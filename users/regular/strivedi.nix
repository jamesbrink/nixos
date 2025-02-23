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
  users.users.strivedi = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDI7GoT7n2YRmjbM1O8Bpr7+ugVTA6mYUR25ZKNF6sDtbhdW6CzpHgAiKMd8yu0GnRNxwtto9/VCEmKru9UBxZtFOIKEkvKEgaxkMZn+NLO5LnE57iIh2UB6nCptQs35NOgQKDoHNPJUpZgv9M1TnOBEpn1K5wyLCRNcNeeJjBNEAkCmFX0434usqOn7hezcZeY8wZf678cJBF9RnKC2toJ2e5QGt6+1gSs12J3JyP5DHWxd8qzxUFz2FMD1tyB1XcJXQCSfqN0I4EaDWWqiexyWaeYy5DmxddAuHDOkUXZ0hjql3486JV20Q0IyWy3e0IZNALuZ1Q62nwY0NW2CmNtD+2RKXzBxjIhyuxmQa8dH3u+J6y/V2bYHHz3uk2g8nVI/gNxkRV0K4r6AgPw8iW07cS0t++ZpARwSKDOcDA6rsA33QeU4AG8w2VjSkVyfaIKbTQ88+tBiIljMrc9pkp5ZORm1dDkT4+WPXp3pAQF/q5f6I3Ld7pGKMDTnVJOBv/NKga6WtAovSHwdpqstwMvmd5d+2QSgVGBqV+Hj7U3zE+28V452OhZZMsBVr+YZ9wthhYlAcGk3jhFjhPLVD488H51yYj2VeklDKFwCTKaXQ5m0l1Iua2MmR647DvDYvRzMhKL+Jb/m8fxCJq2pXO+SR0eCZhTdcmQEXXFGKaaVQ=="
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGeh1TYgVXpFLZglqo2whsob7FY4Mjkz4dYnV7t39LvM"
    ];
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
      atuin
      ffmpeg-full
      imagemagick
      nushell
      xonsh
      yt-dlp
    ];
  };

  home-manager.users.strivedi =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.file."/home/strivedi/.ssh/config_external" = {
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
            "/home/strivedi/.ssh/config_external"
          ];
        };
      };

      home.stateVersion = "24.11";
    };

  security.sudo.extraRules = [
    {
      users = [ "strivedi" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  age.identityPaths = [
    "/home/strivedi/.ssh/id_ed25519"
  ];
}
