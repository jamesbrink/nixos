{
  config,
  pkgs,
  inputs,
  claude-desktop,
  unstablePkgs,
  ...
}:

let
  unstable = unstablePkgs;
in
{
  users.users.jamesbrink = {
    isNormalUser = true;
    description = "James Brink";
    extraGroups = [
      "docker"
      "incus-admin"
      "kvm"
      "libvirtd"
      "networkmanager"
      "qemu-libvirtd"
      "wheel"
      "input"
    ];
    shell = pkgs.zsh;
    useDefaultShell = true;
    packages = with pkgs; [
      (pkgs.callPackage ../../pkgs/llama-cpp {
        cudaSupport = true;
        cudaPackages = pkgs.cudaPackages_12_3;
      })
      claude-desktop.packages.${pkgs.system}.default
      atuin
      barrier
      dbeaver-bin
      discord
      drawio
      ferdium
      ffmpeg-full
      filezilla
      flameshot
      ghostty
      google-chrome
      imagemagick
      insomnia
      jetbrains.datagrip
      legendary-gl
      lens
      mailspring
      meld
      nushell
      obsidian
      openai-whisper-cpp
      postman
      signal-desktop
      termius
      unstable.claude-code
      unstable.code-cursor
      unstable.goose-cli
      unstable.windsurf
      warp-terminal
      waveterm
      wezterm
      winbox4
      wireshark
      xonsh
      yt-dlp
    ];
  };

  home-manager.users.jamesbrink =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.file."/home/jamesbrink/.ssh/config_external" = {
        source = .ssh/config_external;
      };
      home.sessionVariables = {
        SSH_AUTH_SOCK = lib.mkForce "/run/user/$(getent passwd ${config.home.username} | cut -d: -f3)/ssh-agent";
      };
      programs = {
        starship = {
          enable = true;
        };
        zsh = {
          enable = true;
          enableCompletion = true;
          syntaxHighlighting.enable = true;

          oh-my-zsh = {
            enable = true;
            plugins = [
              "git"
              "thefuck"
            ];
            theme = "robbyrussell";
          };

          shellAliases = {
            ll = "ls -l";
            update = "sudo nixos-rebuild switch --flake /etc/nixos/#default";
            cleanup = "sudo nix-collect-garbage -d";
          };

          history.size = 100000;
          initExtraFirst = ''
            if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
              . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
            fi

            # Ripgrep alias
            alias search=rg -p --glob '!node_modules/*'  $@

            # e() {
            #     vim "$@"
            # }

            # nix shortcuts
            shell() {
                nix-shell '<nixpkgs>' -A "$1"
            }

            # Use difftastic, syntax-aware diffing
            alias diff=difft

            # Always color ls and group directories
            alias ls='ls --color=auto'

            # GitHub Token
            export GITHUB_TOKEN="<TBD>"

            ##############
            # AWS Settings
            ##############
            export AWS_PAGER=""
            aws-profile() {
                unset AWS_PROFILE AWS_EB_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
                local profile_name="$1"
                local token_code="$2"
                export AWS_PROFILE="$profile_name"
                export SOURCE_AWS_PROFILE="$AWS_PROFILE"
                export AWS_EB_PROFILE="$profile_name"
                export SOURCE_AWS_EB_PROFIL=E"$AWS_EB_PROFILE"
                caller_identity="$(aws sts get-caller-identity)"
                account_number="$(echo $caller_identity | jq -r '.Account')"
                arn="$(echo $caller_identity | jq -r '.Arn')"
                mfa="$(echo $arn | sed 's|\:user/|\:mfa/|g')"
                export SOURCE_AWS_PROFILE SOURCE_AWS_EB_PROFILE AWS_PROFILE AWS_EB_PROFILE
                if [ -n "$token_code" ]; then
                    AWS_CREDENTIALS="$(aws sts get-session-token --serial-number "$mfa" --token-code "$token_code")"
                    export AWS_ACCESS_KEY_ID="$(echo "$AWS_CREDENTIALS" | jq -r '.Credentials.AccessKeyId')"
                    export SOURCE_AWS_ACCESS_KEY="$AWS_ACCESS_KEY_ID"
                    export AWS_SECRET_ACCESS_KEY="$(echo "$AWS_CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')"
                    export SOURCE_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
                    export AWS_SESSION_TOKEN="$(echo "$AWS_CREDENTIALS" | jq -r '.Credentials.SessionToken')"
                    export SOURCE_AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
                fi
                echo "Using AWS Account: $account_number ($profile_name) - ARN: $arn"
            }

            aws-role() {
                local role_arn="$1"
                eval $(aws sts assume-role --role-arn "$role_arn" --role-session-name "$USER@$HOST" | jq -r '.Credentials | @sh "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)", @sh "export AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)", @sh "export AWS_SESSION_TOKEN=\(.SessionToken)"')
                aws sts get-caller-identity
            }

            aws-no-role() {
                export AWS_PROFILE="$SOURCE_AWS_PROFILE"
                export AWS_EB_PROFILE="$SOURCE_AWS_EB_PROFILE"
                export AWS_ACCESS_KEY_ID="$SOURCE_AWS_ACCESS_KEY_ID"
                export AWS_SECRET_ACCESS_KEY="$SOURCE_AWS_SECRET_ACCESS_KEY"
                export AWS_SESSION_TOKEN="$SOURCE_AWS_SESSION_TOKEN"
            }
          '';
        };
        ssh = {
          enable = true;
          controlMaster = "auto";
          includes = [
            "/home/jamesbrink/.ssh/config_external"
          ];
        };
      };

      home.stateVersion = "24.11";
    };

  security.sudo.extraRules = [
    {
      users = [ "jamesbrink" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  age.identityPaths = [
    "/home/jamesbrink/.ssh/id_ed25519"
  ];

  services.syncthing = {
    enable = true;
    user = "jamesbrink";
    dataDir = "/home/jamesbrink/";
    configDir = "/home/jamesbrink/.config/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "0.0.0.0:8384";

    settings = {
      gui = {
        user = "jamesbrink";
        password = "password";
      };

      devices = {
        "darkstarmk6mod1" = {
          autoAcceptFolders = true;
          id = "A46R3HQ-AW3ODFH-RVOAW4C-P6VFHO5-KHIBRP2-PQLRKIE-YAZTGQO-7QGPCAF";
        };
        "alienware15r4" = {
          id = "LQKOQMG-AIDPDJU-AICPMA4-UPLKWUP-PTWHUNL-IRNJIWD-GY2VU3Q-JLMG6QB";
          autoAcceptFolders = true;
        };
        "n100-01" = {
          autoAcceptFolders = true;
          id = "HCRYHXP-QXLM4FW-SIPYBNL-IOLODXZ-PM5FX7W-3DOQ4ED-GJ5YNSK-LVUJQAA";
        };
        "n100-02" = {
          autoAcceptFolders = true;
          id = "KICZH4D-WJIVHZM-EW2CN5A-WEF44ZA-VAXR7MY-AWTQOXC-APLRSQP-TQCOBQX";
        };
        "n100-03" = {
          autoAcceptFolders = true;
          id = "WYTVEJT-WTMRX73-N3ASBH2-AAHMD5R-N3FUI3M-XXYQAVH-O6GDDU4-LUQVHAT";
        };
        "hal9000" = {
          autoAcceptFolders = true;
          id = "PRCPMWC-H6VGK4G-6X2QQDH-P6UOLJJ-JTLDNYW-LIKBC5X-6WM4T2R-Q5TZEAR";
        };
      };

      folders = {
        "Projects" = {
          path = "/home/jamesbrink/Projects";
          devices = [
            "darkstarmk6mod1"
            "alienware15r4"
            "n100-01"
            "n100-02"
            "n100-03"
            "hal9000"
          ];
          label = "Projects";
          enable = false;
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [
            "darkstarmk6mod1"
            "alienware15r4"
            "n100-01"
            "n100-02"
            "n100-03"
            "hal9000"
          ];
          label = "Documents";
          enable = false;
        };
      };
    };
  };
}
