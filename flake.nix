{
  description = "NixOS System Configurations";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.05";
    };
    nixos-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    secrets = {
      url = "git+ssh://git@github.com/jamesbrink/nix-secrets.git";
      flake = false;
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    claude-desktop = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    devshell = {
      url = "github:numtide/devshell";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-unstable,
      home-manager,
      home-manager-unstable,
      agenix,
      secrets,
      vscode-server,
      claude-desktop,
      devshell,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          (final: prev: {
            unstablePkgs = import nixos-unstable {
              inherit system;
              config = {
                allowUnfree = true;
              };
            };
          })
        ];
      };
    in
    {
      #########################################################################
      # Development Shells                                                    #
      #########################################################################

      devShells = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ devshell.overlays.default ];
            config.allowUnfree = true;
          };

        in
        # Note: We can't detect hostname at evaluation time in pure Nix
        # We'll use shell commands at runtime instead
        {
          default = pkgs.devshell.mkShell {
            name = "nix-config-dev";

            # Allow unfree packages in the devshell
            env = [
              {
                name = "NIXPKGS_ALLOW_UNFREE";
                value = "1";
              }
            ];

            packages = with pkgs; [
              nixfmt-rfc-style
              treefmt
              rsync
              openssh
              nodePackages.prettier # For JSON and HTML formatting
              jq # For JSON processing
            ];

            commands = [
              # ───────────────────────────────────────────────────────
              # DEVELOPMENT COMMANDS - For local development work
              # ───────────────────────────────────────────────────────
              {
                name = "format";
                category = "development";
                help = "Format all Nix files using treefmt";
                command = ''
                  echo "Formatting files using treefmt..."
                  treefmt
                  if [ $? -eq 0 ]; then
                    echo "Formatting complete!"
                  else
                    echo "Formatting failed. Check the error messages above."
                    exit 1
                  fi
                '';
              }

              # ───────────────────────────────────────────────────────
              # DEPLOYMENT COMMANDS - For updating the hosts
              # ───────────────────────────────────────────────────────
              {
                name = "deploy";
                category = "deployment";
                help = "Deploy the configuration to a target host";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: deploy <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  echo "Deploying configuration to $HOST..."

                  # Check if we're on the target host
                  if [ "$HOSTNAME" = "$HOST" ]; then
                    echo "Deploying locally to $HOST..."
                    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake .#$HOST --verbose --impure
                  else
                    echo "Deploying remotely to $HOST..."
                    # Copy the flake to the remote server and build there
                    rsync -avz --exclude '.git' --exclude 'result' . root@$HOST:/tmp/nixos-config/
                    ssh root@$HOST "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake .#$HOST --verbose --impure"
                  fi

                  echo "Deployment to $HOST complete!"
                '';
              }

              {
                name = "deploy-test";
                category = "deployment";
                help = "Test the deployment without making changes";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: deploy-test <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  echo "Testing deployment to $HOST..."

                  # Check if we're on the target host
                  if [ "$HOSTNAME" = "$HOST" ]; then
                    echo "Testing locally on $HOST..."
                    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#$HOST --impure
                  else
                    echo "Testing remotely on $HOST..."
                    # Copy the flake to the remote server and test there
                    rsync -avz --exclude '.git' --exclude 'result' . root@$HOST:/tmp/nixos-config/
                    ssh root@$HOST "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#$HOST --impure"
                  fi

                  echo "Deployment test for $HOST complete!"
                '';
              }

              {
                name = "update";
                category = "deployment";
                help = "Update NixOS and flake inputs";
                command = ''
                  echo "Updating NixOS and flake inputs..."
                  NIXPKGS_ALLOW_UNFREE=1 nix flake update --impure
                  echo "Update complete! You may now run 'deploy <hostname>' to apply the updates."
                '';
              }

              {
                name = "update-input";
                category = "deployment";
                help = "Update a specific flake input";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    echo "Error: You must specify an input name."
                    echo "Usage: update-input <input-name>"
                    echo "Available inputs:"
                    nix flake metadata --json | jq -r '.locks.nodes | keys[]'
                    exit 1
                  fi

                  INPUT="$1"
                  echo "Updating flake input '$INPUT'..."
                  NIXPKGS_ALLOW_UNFREE=1 nix flake lock --update-input "$INPUT" --impure
                  echo "Update of '$INPUT' complete! You may now run 'deploy <hostname>' to apply the updates."
                '';
              }

              {
                name = "build";
                category = "deployment";
                help = "Build the configuration for a target host without deploying";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: build <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  echo "Building configuration for $HOST..."
                  NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#nixosConfigurations.$HOST.config.system.build.toplevel
                  echo "Build for $HOST complete!"
                '';
              }

              {
                name = "deploy-local";
                category = "deployment";
                help = "Build locally and deploy to a remote host (useful for low-RAM targets)";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: deploy-local <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  # Check if we're trying to deploy to ourselves
                  if [ "$HOSTNAME" = "$HOST" ]; then
                    echo "Error: deploy-local is for remote hosts only. Use 'deploy' for local deployment."
                    exit 1
                  fi

                  # Check if we already have a build result
                  if [ -L ./result ] && [ -e ./result ]; then
                    # Verify this result is for the correct host
                    RESULT_HOST=$(readlink ./result | grep -oP 'nixos-system-\K[^-]+' || echo "unknown")
                    if [ "$RESULT_HOST" = "$HOST" ]; then
                      echo "Found existing build result for $HOST, using it..."
                    else
                      echo "Existing build result is for '$RESULT_HOST', not '$HOST'. Building fresh..."
                      NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#nixosConfigurations.$HOST.config.system.build.toplevel
                      if [ $? -ne 0 ]; then
                        echo "Build failed! Aborting deployment."
                        exit 1
                      fi
                    fi
                  else
                    echo "No existing build result found. Building configuration for $HOST locally..."
                    NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#nixosConfigurations.$HOST.config.system.build.toplevel
                    if [ $? -ne 0 ]; then
                      echo "Build failed! Aborting deployment."
                      exit 1
                    fi
                  fi

                  echo "Build complete! Copying closure to $HOST..."
                  nix-copy-closure --to root@$HOST ./result
                  
                  if [ $? -ne 0 ]; then
                    echo "Failed to copy closure to $HOST! Aborting deployment."
                    exit 1
                  fi

                  echo "Switching to new configuration on $HOST..."
                  STORE_PATH=$(readlink -f ./result)
                  ssh root@$HOST "nix-env -p /nix/var/nix/profiles/system --set $STORE_PATH && /nix/var/nix/profiles/system/bin/switch-to-configuration switch"
                  
                  if [ $? -eq 0 ]; then
                    echo "Deployment to $HOST complete!"
                  else
                    echo "Failed to switch configuration on $HOST!"
                    exit 1
                  fi
                '';
              }

              {
                name = "check";
                category = "development";
                help = "Check the Nix expressions for errors";
                command = ''
                  echo "Checking Nix expressions for errors..."
                  NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure
                  echo "Check complete!"
                '';
              }

              # ───────────────────────────────────────────────────────
              # MAINTENANCE COMMANDS - For system maintenance
              # ───────────────────────────────────────────────────────
              {
                name = "health-check";
                category = "maintenance";
                help = "Check the health of a system";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: health-check <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  echo "Checking system health on $HOST..."

                  if [ "$HOSTNAME" = "$HOST" ]; then
                    # Local health check
                    echo "\nDisk usage on $HOST:"
                    df -h | grep -v tmpfs
                    echo "\nMemory usage on $HOST:"
                    free -h
                    echo "\nSystem load on $HOST:"
                    uptime
                    echo "\nFailed services on $HOST:"
                    systemctl --failed
                    echo "\nJournal errors on $HOST (last 10):"
                    journalctl -p 3 -xn 10
                  else
                    # Remote health check
                    echo "\nDisk usage on $HOST:"
                    ssh root@$HOST "df -h | grep -v tmpfs"
                    echo "\nMemory usage on $HOST:"
                    ssh root@$HOST "free -h"
                    echo "\nSystem load on $HOST:"
                    ssh root@$HOST "uptime"
                    echo "\nFailed services on $HOST:"
                    ssh root@$HOST "systemctl --failed"
                    echo "\nJournal errors on $HOST (last 10):"
                    ssh root@$HOST "journalctl -p 3 -xn 10"
                  fi

                  echo "\nHealth check for $HOST complete."
                '';
              }

              {
                name = "gc";
                category = "maintenance";
                help = "Run garbage collection to free up disk space";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: gc <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  echo "Running garbage collection on $HOST..."

                  if [ "$HOSTNAME" = "$HOST" ]; then
                    # Local garbage collection
                    sudo nix-collect-garbage -d
                  else
                    # Remote garbage collection
                    ssh root@$HOST "nix-collect-garbage -d"
                  fi

                  echo "Garbage collection on $HOST complete!"
                '';
              }

              {
                name = "show-hosts";
                category = "maintenance";
                help = "Show all available hosts";
                command = ''
                  echo "Available hosts:"
                  find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                '';
              }

              {
                name = "show-generations";
                category = "maintenance";
                help = "Show NixOS generations on a host";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: show-generations <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  if [ "$HOSTNAME" = "$HOST" ]; then
                    # Local generations
                    echo "NixOS generations on $HOST:"
                    sudo nix-env -p /nix/var/nix/profiles/system --list-generations
                  else
                    # Remote generations
                    echo "NixOS generations on $HOST:"
                    ssh root@$HOST "nix-env -p /nix/var/nix/profiles/system --list-generations"
                  fi
                '';
              }

              {
                name = "rollback";
                category = "maintenance";
                help = "Rollback to the previous generation on a host";
                command = ''
                  # Check if argument is provided
                  if [ $# -eq 0 ]; then
                    HOST=""
                  else
                    HOST="$1"
                  fi
                  if [ -z "$HOST" ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: rollback <hostname>"
                    echo "Available hosts:"
                    find ./hosts -maxdepth 1 -mindepth 1 -type d | sort | sed 's|./hosts/||'
                    exit 1
                  fi

                  HOSTNAME=$(hostname)

                  echo "Rolling back to previous generation on $HOST..."

                  if [ "$HOSTNAME" = "$HOST" ]; then
                    # Local rollback
                    sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild --rollback switch --impure
                  else
                    # Remote rollback
                    ssh root@$HOST "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild --rollback switch --impure"
                  fi

                  echo "Rollback on $HOST complete!"
                '';
              }
            ];
          };
        }
      );

      #########################################################################
      # NixOS Configurations                                                  #
      #########################################################################

      nixosConfigurations = {
        n100-01 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            ./hosts/n100-01/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
          ];
        };

        n100-03 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            ./hosts/n100-03/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
          ];
        };

        n100-04 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit
              inputs
              agenix
              self
              claude-desktop
              ;
            secretsPath = "${inputs.secrets}";
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            vscode-server.nixosModules.default
            (
              { config, pkgs, ... }:
              {
                services.vscode-server.enable = true;
              }
            )
            ./hosts/n100-04/default.nix

            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
          ];
        };

        alienware = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            ./hosts/alienware/default.nix
          ];
        };

        hal9000 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit
              inputs
              agenix
              self
              claude-desktop
              ;
            secretsPath = "${inputs.secrets}";
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            vscode-server.nixosModules.default
            (
              { config, pkgs, ... }:
              {
                services.vscode-server.enable = true;
              }
            )
            ./hosts/hal9000/default.nix

            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
          ];
        };

        sevastopol = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            vscode-server.nixosModules.default
            (
              { config, pkgs, ... }:
              {
                services.vscode-server.enable = true;
              }
            )
            ./hosts/sevastopol/default.nix

            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
          ];
        };
      };
    };
}
