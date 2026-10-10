# Omarchy v4 desktop via nixarchy, offered as its own "Omarchy" session next to
# the existing Hyprland session. Omarchy's Quickshell shell brings the bar,
# menus, Wi-Fi/Bluetooth/audio/display panels, agent integration and theming.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Omarchy with local changes:
  # - its idle screensaver plays the video screensavers (hypr-launch-screensaver,
  #   from modules/home-manager/hyprland) instead of the terminal text effect;
  # - theme switches reload open terminals. Upstream matches `pgrep -x ghostty`,
  #   but nixpkgs' wrappers run as `.ghostty-wrappe` / `.kitty-wrapped`;
  # - volume keys play a feedback blip;
  # - the Windows VM helper works outside an FHS layout (see below).
  omarchy = (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      cat > $out/share/omarchy/bin/omarchy-launch-screensaver <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      # omarchy:summary=Launch the video screensaver (nixarchy override).
      exec hypr-launch-screensaver "$@"
      SCRIPT
      chmod +x $out/share/omarchy/bin/omarchy-launch-screensaver

      cat > $out/share/omarchy/bin/omarchy-restart-terminal <<'SCRIPT'
      #!${pkgs.bash}/bin/bash
      # omarchy:summary=Reload supported terminal emulators after config changes
      if [[ -f ~/.config/alacritty/alacritty.toml ]]; then
        touch ~/.config/alacritty/alacritty.toml
      fi
      ${pkgs.procps}/bin/pkill -USR1 -x '\.?kitty(-wrapped?)?' || true
      ${pkgs.procps}/bin/pkill -USR2 -x '\.?ghostty(-wrappe(d)?)?' || true
      SCRIPT
      chmod +x $out/share/omarchy/bin/omarchy-restart-terminal

      # Windows VM (dockur/windows): upstream assumes an FHS layout. Its root
      # helper must be /usr/bin/omarchy-windows-vm with a root-only-writable
      # path up to /, and the privileged side pins PATH to /usr/bin. Point both
      # at the immutable store copy (/nix/store itself is 1775 root:nixbld, so
      # the ownership walk stops there) and at the root-owned system profile.
      substituteInPlace $out/share/omarchy/bin/omarchy-windows-vm \
        --replace-fail 'local candidate=/usr/bin/omarchy-windows-vm' \
          "local candidate=$out/share/omarchy/bin/omarchy-windows-vm" \
        --replace-fail "    owner=\$(stat -Lc '%u' \"\$probe\" 2>/dev/null) || return 1" \
          "    [[ \$probe == /nix/store ]] && break; owner=\$(stat -Lc '%u' \"\$probe\" 2>/dev/null) || return 1" \
        --replace-fail 'export PATH=/usr/bin:/usr/sbin:/bin:/sbin' \
          'export PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin' \
        --replace-fail 'TREE_SCAN_TIMEOUT=/usr/bin/timeout' 'TREE_SCAN_TIMEOUT=${pkgs.coreutils}/bin/timeout' \
        --replace-fail 'TREE_SCAN_FIND=/usr/bin/find' 'TREE_SCAN_FIND=${pkgs.findutils}/bin/find' \
        --replace-fail 'xfreerdp3 /u:' '${pkgs.freerdp}/bin/xfreerdp /u:'

      # Volume keys play the freedesktop change blip (at 50%), as the legacy
      # Hyprland setup did; skipped for mute toggles and while muted.
      substituteInPlace $out/share/omarchy/bin/omarchy-audio-output-volume \
        --replace-fail 'omarchy-osd -i "$icon"' 'if [[ $action != mute-toggle ]] && ! volume_muted; then
        ${pkgs.pulseaudio}/bin/paplay --volume=32768 ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null &
      fi
      omarchy-osd -i "$icon"'
    '';
  });
in
{
  imports = [ inputs.nixarchy.nixosModules.nixarchy ];

  programs.nixarchy = {
    enable = true;
    package = omarchy;
    user = "jamesbrink";
    defaultAgent = "claude";
    # Keep our SDDM (autologin + theme) instead of nixarchy's greeter.
    displayManager = false;
    # Keep the existing boot (no Plymouth splash).
    bootSplash = "off";
  };

  # Autologin straight into the Omarchy session.
  services.displayManager.defaultSession = lib.mkForce "omarchy";

  # nixarchy defaults to linuxPackages_latest; stay on the release kernel so
  # ZFS and the NVIDIA driver keep matching what nixpkgs tests together.
  boot.kernelPackages = pkgs.linuxPackages;

  # Keep the Hyprland the rest of the system already uses (0.55, from nixpkgs).
  programs.hyprland.package = lib.mkForce pkgs.hyprland;
  programs.hyprland.portalPackage = lib.mkForce pkgs.xdg-desktop-portal-hyprland;

  # Taildrop: save files sent from other tailnet devices into ~/Downloads.
  # Upstream ships this unit with /usr/bin paths and only enables it from its
  # own Tailscale installer, so it is declared here like nixarchy's other units.
  systemd.user.services.omarchy-tailscale-receive = lib.mkIf config.services.tailscale.enable {
    description = "Save incoming Taildrop files to the downloads directory";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    path = [
      omarchy
      config.services.tailscale.package
      pkgs.xdg-utils
    ];
    environment.OMARCHY_PATH = "${omarchy}/share/omarchy";
    serviceConfig = {
      ExecStart = "${omarchy}/bin/omarchy-tailscale-receive";
      Restart = "always";
      RestartSec = 5;
    };
  };

  home-manager.users.jamesbrink =
    hm:
    let
      # Starship prompt. Trying Omarchy's stock prompt (cyan, two-level path,
      # git status glyphs). To go back to the themectl-style one, swap these two
      # lines and uncomment the hook + activation further down.
      starshipConfig = "${omarchy}/share/omarchy/config/starship.toml";
      # starshipConfig = starshipThemedConfig;

      # Themed starship prompt, as themectl rendered it: the static settings from
      # modules/home-manager/shell/starship.nix with the theme's accent color
      # swapped in. Omarchy v4 themes ship no starship.toml, so a theme-set hook
      # renders it from colors.toml.
      starshipThemedConfig = "${hm.config.xdg.stateHome}/omarchy/starship.toml";
      starshipTemplate = (pkgs.formats.toml { }).generate "starship-themed.toml" (
        lib.recursiveUpdate hm.config.programs.starship.settings {
          username.style_user = "@ACCENT@ bold";
          hostname.style = "dimmed @ACCENT@";
          directory.style = "@ACCENT@ bold";
          git_branch.style = "@ACCENT@ bold";
          character.success_symbol = "[❯](bold @ACCENT@)";
          nodejs.format = "via [⬢ $version](bold @ACCENT@) ";
          golang.format = "via [🐹 $version](bold @ACCENT@) ";
          kubernetes.format = "on [⛵ $context\\($namespace\\)](@ACCENT@ bold) ";
          nix_shell = {
            format = "via [❄️ $state( \\($name\\))](@ACCENT@ bold) ";
            pure_msg = "[pure](bold @ACCENT@)";
          };
        }
      );
      renderStarship = pkgs.writeShellScript "omarchy-starship-theme" ''
        colors="${hm.config.xdg.stateHome}/omarchy/current/theme/colors.toml"
        accent=$(${pkgs.gnused}/bin/sed -n 's/^accent *= *"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$colors" 2>/dev/null)
        mkdir -p "$(dirname ${starshipThemedConfig})"
        ${pkgs.gnused}/bin/sed "s/@ACCENT@/''${accent:-green}/g" ${starshipTemplate} >"${starshipThemedConfig}.tmp"
        mv "${starshipThemedConfig}.tmp" "${starshipThemedConfig}"
      '';
    in
    {
      imports = [ inputs.nixarchy.homeManagerModules.nixarchy ];
      programs.nixarchy = {
        enable = true;
        package = omarchy;
      };
      # nixi (guided tour) pulls codex-acp, which fails to link on 26.05.
      services.nixi.enable = false;

      # omarchy-shell replaces the legacy desktop shell from
      # modules/home-manager/hyprland: bar, notifications, OSD, idle/lock.
      programs.waybar.enable = lib.mkForce false;
      services.mako.enable = lib.mkForce false;
      services.hypridle.enable = lib.mkForce false;
      # themectl writes Omarchy-v3 themes into ~/.config/omarchy/themes, which
      # Omarchy v4 reads as user-installed themes. It stays on Darwin.
      programs.themectl.enable = lib.mkForce false;

      # Hide tray apps the shell replaces with its Wi-Fi, Bluetooth and polkit panels.
      xdg.configFile =
        lib.genAttrs
          (map (n: "autostart/${n}.desktop") [
            "blueman"
            "iwgtk-indicator"
            "nm-applet"
            "polkit-gnome-authentication-agent-1"
          ])
          (_: {
            text = "[Desktop Entry]\nType=Application\nHidden=true\n";
          });

      # No HEY: hide its webapp launcher (keybindings are unbound in the
      # Omarchy-owned ~/.config/hypr/bindings.lua).
      xdg.dataFile."applications/omarchy-HEY.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=HEY
        Hidden=true
      '';

      # Default terminal is Ghostty. Seeded rather than linked: Omarchy's
      # "default terminal" menu rewrites this file, which a store symlink blocks.
      home.activation.seedDefaultTerminal = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        list="$HOME/.config/xdg-terminals.list"
        if [[ ! -e $list ]]; then
          $DRY_RUN_CMD printf '%s\n' com.mitchellh.ghostty.desktop >"$list"
        fi
      '';

      # Themed starship (off while trying Omarchy's prompt; see starshipConfig).
      # home.file.".config/omarchy/hooks/theme-set.d/starship".text = ''
      #   exec ${renderStarship}
      # '';
      # home.activation.renderStarshipTheme = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #   $DRY_RUN_CMD ${renderStarship}
      # '';
      home.sessionVariables.STARSHIP_CONFIG = lib.mkForce starshipConfig;
      # Also set per shell: sessions started before a rebuild keep a stale value.
      programs.zsh.initContent = ''
        export STARSHIP_CONFIG="${starshipConfig}"
      '';
    };
}
