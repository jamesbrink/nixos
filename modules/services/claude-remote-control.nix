# Persistent `claude remote-control` servers.
#
# Runs one standing Remote Control server per configured directory so the
# Claude phone app / claude.ai/code can start new Claude Code sessions on this
# machine without a terminal already open. Works on both nix-darwin (launchd
# user agent in the GUI login session, so the keychain credentials are
# reachable) and NixOS (systemd --user service; the user must linger).
#
# Constraints from https://code.claude.com/docs/en/remote-control:
# - Needs a full `claude auth login` (setup-token / OAuth env tokens are rejected).
# - Each directory must already be trusted by an interactive `claude` run.
#   Never root a server at $HOME.
# - The environment must not carry DISABLE_TELEMETRY, DO_NOT_TRACK,
#   CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC, DISABLE_GROWTHBOOK,
#   ANTHROPIC_BASE_URL or ANTHROPIC_API_KEY.
# - Flags go after `remote-control`; global flags before it are refused.
#
# The `claude` binary comes from the native installer (~/.local/bin/claude),
# not nixpkgs, so `binary` is a runtime path expanded by the shell.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  cfg = config.services.claude-remote-control;
  isDarwin = options ? launchd;

  # PATH the servers (and every session they spawn) inherit.
  defaultPath =
    if isDarwin then
      [
        "$HOME/.local/bin"
        "/etc/profiles/per-user/$USER/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/opt/homebrew/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ]
    else
      [
        "$HOME/.local/bin"
        "$HOME/.nix-profile/bin"
        "/etc/profiles/per-user/$USER/bin"
        "/run/wrappers/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/bin"
        "/bin"
      ];

  defaultLogDirectory =
    if isDarwin then
      "$HOME/Library/Logs/claude-remote-control"
    else
      "$HOME/.local/state/claude-remote-control";

  serverModule =
    { name, ... }:
    {
      options = {
        directory = lib.mkOption {
          type = lib.types.str;
          description = "Directory the server runs in. Must already be trusted; never $HOME.";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = "${config.networking.hostName}-${name}";
          description = "Session name shown in claude.ai/code and the mobile app.";
        };
        spawn = lib.mkOption {
          type = lib.types.enum [
            "same-dir"
            "worktree"
          ];
          default = "same-dir";
          description = "Where on-demand sessions run: the directory itself or an isolated git worktree.";
        };
        permissionMode = lib.mkOption {
          type = lib.types.enum [
            "acceptEdits"
            "auto"
            "bypassPermissions"
            "default"
            "dontAsk"
            "plan"
          ];
          default = "acceptEdits";
          description = "Permission mode for spawned sessions.";
        };
        capacity = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.positive;
          default = null;
          description = "Max concurrent sessions (claude default: 32).";
        };
        createSessionInDir = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Pre-create one session in the directory so the machine shows as online immediately.";
        };
        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional arguments appended after `remote-control`.";
        };
      };
    };

  serverArgs =
    server:
    [
      "--name"
      server.name
      "--spawn"
      server.spawn
      "--permission-mode"
      server.permissionMode
    ]
    ++ lib.optionals (server.capacity != null) [
      "--capacity"
      (toString server.capacity)
    ]
    ++ lib.optional (!server.createSessionInDir) "--no-create-session-in-dir"
    ++ server.extraArgs;

  # One wrapper per server. It owns the log file and the environment so the
  # launchd/systemd unit definitions stay trivial and identical in behavior.
  mkWrapper =
    id: server:
    pkgs.writeShellScript "claude-remote-control-${id}" ''
      set -euo pipefail
      export PATH="${lib.concatStringsSep ":" cfg.path}"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''export ${k}="${v}"'') cfg.environment)}
      # Remote Control refuses to run with any of these set.
      unset DISABLE_TELEMETRY DO_NOT_TRACK CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
        DISABLE_GROWTHBOOK ANTHROPIC_BASE_URL ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDECODE
      log_dir="${cfg.logDirectory}"
      mkdir -p "$log_dir"
      cd "${server.directory}"
      echo "[$(date -u +%FT%TZ)] starting ${server.name} in ${server.directory}" >> "$log_dir/${id}.log"
      exec "${cfg.binary}" remote-control ${lib.escapeShellArgs (serverArgs server)} \
        >> "$log_dir/${id}.log" 2>&1
    '';

  unitName = id: "claude-remote-control-${id}";
in
{
  options.services.claude-remote-control = {
    enable = lib.mkEnableOption "persistent claude remote-control servers";

    user = lib.mkOption {
      type = lib.types.str;
      default = "jamesbrink";
      description = "User whose Claude credentials and login session the servers run under.";
    };

    binary = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/bin/claude";
      description = "Path to the native-installer `claude` binary (shell-expanded at runtime).";
    };

    path = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = defaultPath;
      description = "PATH entries for the servers and the sessions they spawn (shell-expanded at runtime).";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables exported before starting each server.";
    };

    logDirectory = lib.mkOption {
      type = lib.types.str;
      default = defaultLogDirectory;
      description = "Directory for per-server log files (shell-expanded at runtime).";
    };

    servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule serverModule);
      default = { };
      description = "Remote Control servers to run, one per directory.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = lib.mapAttrsToList (id: server: {
          assertion =
            !builtins.elem (lib.removeSuffix "/" server.directory) [
              "/Users/${cfg.user}"
              "/home/${cfg.user}"
            ];
          message = "services.claude-remote-control.servers.${id}: refusing to root a server at the home directory (${server.directory}).";
        }) cfg.servers;
      }

      (lib.optionalAttrs isDarwin {
        launchd.user.agents = lib.mapAttrs' (
          id: server:
          lib.nameValuePair (unitName id) {
            serviceConfig = {
              ProgramArguments = [ (toString (mkWrapper id server)) ];
              KeepAlive = true;
              RunAtLoad = true;
              ThrottleInterval = 10;
              ProcessType = "Interactive";
              StandardOutPath = "/tmp/${unitName id}.launchd.log";
              StandardErrorPath = "/tmp/${unitName id}.launchd.log";
            };
          }
        ) cfg.servers;
      })

      (lib.optionalAttrs (!isDarwin) {
        systemd.user.services = lib.mapAttrs' (
          id: server:
          lib.nameValuePair (unitName id) {
            description = "Claude Remote Control server (${server.name})";
            wantedBy = [ "default.target" ];
            unitConfig.ConditionUser = cfg.user;
            serviceConfig = {
              Type = "simple";
              ExecStart = toString (mkWrapper id server);
              Restart = "always";
              RestartSec = 10;
              KillMode = "mixed";
            };
          }
        ) cfg.servers;
      })
    ]
  );
}
