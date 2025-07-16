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
      # Using path input - rsync will handle copying the actual files
      url = "path:./secrets";
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
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Darwin-specific inputs
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    nix-homebrew = {
      url = "github:zhaofengli/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixos-unstable";
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
      disko,
      darwin,
      nix-homebrew,
      homebrew-bundle,
      homebrew-core,
      homebrew-cask,
      zen-browser,
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
              {
                name = "EDITOR";
                value = "nvim";
              }
              {
                name = "PRJ_ROOT";
                eval = "$PWD";
              }
            ];

            packages = with pkgs; [
              nixfmt-rfc-style
              treefmt
              rsync
              openssh
              nodePackages.prettier # For JSON and HTML formatting
              jq # For JSON processing
              age # For secrets encryption
              (pkgs.callPackage "${inputs.agenix}/pkgs/agenix.nix" { }) # agenix from flake input
              nixos-anywhere # For initial deployments with disko
              shellcheck # For shell script linting
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
                command = "${./scripts/deploy.sh} $@";
              }

              {
                name = "deploy-test";
                category = "deployment";
                help = "Test the deployment without making changes";
                command = "${./scripts/deploy-test.sh} $@";
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

                  # Check if host exists in nixosConfigurations or darwinConfigurations
                  if nix eval --json .#nixosConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                    NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#nixosConfigurations.$HOST.config.system.build.toplevel
                  elif nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                    NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#darwinConfigurations.$HOST.system
                  else
                    echo "Error: Host '$HOST' not found in nixosConfigurations or darwinConfigurations"
                    exit 1
                  fi

                  echo "Build for $HOST complete!"
                '';
              }

              {
                name = "deploy-all";
                category = "deployment";
                help = "Deploy to all hosts in parallel with a summary report";
                command = ''
                  ${./scripts/deploy-all.sh} "$@"
                '';
              }
              {
                name = "deploy-local";
                category = "deployment";
                help = "Build locally and deploy to a remote host (useful for low-RAM targets)";
                command = "${./scripts/deploy-local.sh} $@";
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
                command = "${./scripts/health-check.sh} $@";
              }

              {
                name = "nix-gc";
                category = "maintenance";
                help = "Run garbage collection to free up disk space";
                command = "${./scripts/nix-gc.sh} $@";
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
                command = "${./scripts/show-generations.sh} $@";
              }

              {
                name = "rollback";
                category = "maintenance";
                help = "Rollback to the previous generation on a host";
                command = "${./scripts/rollback.sh} $@";
              }

              {
                name = "secrets-edit";
                category = "secrets";
                help = "Edit a secret file";
                command = "${./scripts/secrets-edit.sh} $@";
              }

              {
                name = "secrets-rekey";
                category = "secrets";
                help = "Re-encrypt all secrets with current recipients";
                command = "${./scripts/secrets-rekey.sh} $@";
              }

              {
                name = "secrets-list";
                category = "secrets";
                help = "List all secret files";
                command = ''
                  echo "Available secrets:"
                  find secrets -name "*.age" -type f | sort | sed 's|^secrets/||; s|\.age$||'
                '';
              }

              {
                name = "secrets-verify";
                category = "secrets";
                help = "Verify all secrets can be decrypted";
                command = "${./scripts/secrets-verify.sh} $@";
              }

              {
                name = "secrets-sync";
                category = "secrets";
                help = "Pull latest secrets from the submodule";
                command = ''
                  echo "Updating secrets submodule..."
                  git submodule update --remote --merge secrets
                  echo "Secrets submodule updated"
                '';
              }

              {
                name = "secrets-add-host";
                category = "secrets";
                help = "Add a new host to secrets recipients";
                command = "${./scripts/secrets-add-host.sh} $@";
              }

              # ───────────────────────────────────────────────────────
              # NETBOOT COMMANDS - For netboot infrastructure
              # ───────────────────────────────────────────────────────
              {
                name = "netboot-build";
                category = "netboot";
                help = "Build and deploy N100 netboot images";
                command = ''
                  NIX_CONFIG_DIR="${toString ./.}" ${./scripts/build-netboot-images.sh}
                '';
              }

              {
                name = "netboot-setup-macs";
                category = "netboot";
                help = "Document N100 MAC addresses for netboot";
                command = ''
                  echo "Setting up N100 MAC addresses..."
                  cd ${toString ./.}
                  ./scripts/setup-n100-macs.sh
                '';
              }

              {
                name = "deploy-n100";
                category = "netboot";
                help = "Initial deployment to N100 node using nixos-anywhere (creates ZFS volumes). Use NIXOS_ANYWHERE_NOCONFIRM=1 to skip confirmation";
                command = "${./scripts/deploy-n100.sh} $@";
              }

              {
                name = "deploy-n100-local";
                category = "netboot";
                help = "Initial deployment to N100 node using nixos-anywhere with local build (for resource-constrained targets)";
                command = "${./scripts/deploy-n100-local.sh} $@";
              }

              {
                name = "secrets-print";
                category = "secrets";
                help = "Decrypt and print a secret (for testing/debugging)";
                command = "${./scripts/secrets-print.sh} $@";
              }

              # Backup commands
              {
                name = "restic-status";
                category = "backup";
                help = "Check Restic backup status on all hosts";
                command = "${./scripts/restic-status.sh} $@";
              }

              {
                name = "restic-run";
                category = "backup";
                help = "Manually trigger backup on a specific host";
                command = "${./scripts/restic-run.sh} $@";
              }

              {
                name = "restic-snapshots";
                category = "backup";
                help = "List snapshots for a host";
                command = "RESTIC_PATH=${pkgs.restic}/bin/restic ${./scripts/restic-snapshots.sh} $@";
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
            disko.nixosModules.disko
            ./hosts/n100-01/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                    overlays = [ ];
                  };
                })
              ];
            }
          ];
        };

        n100-02 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            disko.nixosModules.disko
            ./hosts/n100-02/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                    overlays = [ ];
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
            disko.nixosModules.disko
            ./hosts/n100-03/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                    overlays = [ ];
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
            disko.nixosModules.disko
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
                    overlays = [ ];
                  };
                })
              ];
            }
          ];
        };

        alienware = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              inherit system;
              config.allowUnfree = true;
              overlays = [ ];
            };
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            ./hosts/alienware/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                    overlays = [ ];
                  };
                })
              ];
            }
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
                    overlays = [ ];
                  };
                })
              ];
            }
          ];
        };

        sevastopol-linux = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              inherit system;
              config.allowUnfree = true;
              overlays = [ ];
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
            ./hosts/sevastopol-linux/default.nix

            # Use unstable packages
            {
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-linux";
                    config.allowUnfree = true;
                    overlays = [ ];
                  };
                })
              ];
            }
          ];
        };
      };

      #########################################################################
      # Darwin Configurations                                                 #
      #########################################################################

      darwinConfigurations = {
        halcyon = darwin.lib.darwinSystem {
          system = "aarch64-darwin"; # M4 Mac

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              system = "aarch64-darwin";
              config.allowUnfree = true;
              overlays = [ ];
            };
          };

          modules = [
            home-manager-unstable.darwinModules.home-manager
            agenix.darwinModules.default
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                user = "jamesbrink";
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };
                mutableTaps = true;
                autoMigrate = true;
              };
            }
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "aarch64-darwin";
                    config.allowUnfree = true;
                  };
                })
              ];
            }
            ./hosts/halcyon/default.nix
          ];
        };

        sevastopol = darwin.lib.darwinSystem {
          system = "x86_64-darwin"; # Intel iMac 27" 2013

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              system = "x86_64-darwin";
              config.allowUnfree = true;
              overlays = [ ];
            };
          };

          modules = [
            home-manager-unstable.darwinModules.home-manager
            agenix.darwinModules.default
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                user = "jamesbrink";
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };
                mutableTaps = true;
                autoMigrate = true;
              };
            }
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-darwin";
                    config.allowUnfree = true;
                    overlays = [ ];
                  };
                })
              ];
            }
            ./hosts/sevastopol/default.nix
          ];
        };

        darkstarmk6mod1 = darwin.lib.darwinSystem {
          system = "x86_64-darwin"; # 2019 MacBook Pro 16" Intel

          specialArgs = {
            inherit inputs agenix claude-desktop;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              system = "x86_64-darwin";
              config.allowUnfree = true;
              overlays = [ ];
            };
          };

          modules = [
            home-manager-unstable.darwinModules.home-manager
            agenix.darwinModules.default
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                user = "jamesbrink";
                enable = true;
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };
                mutableTaps = true;
                autoMigrate = true;
              };
            }
            {
              nixpkgs.config.allowUnfree = true;
              nixpkgs.overlays = [
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "x86_64-darwin";
                    config.allowUnfree = true;
                    overlays = [ ];
                  };
                })
              ];
            }
            ./hosts/darkstarmk6mod1/default.nix
          ];
        };
      };
    };
}
