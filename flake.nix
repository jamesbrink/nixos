{
  description = "NixOS System Configurations";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };
    nixos-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
    omarchy = {
      url = "path:./external/omarchy";
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
    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
    };
    invokeai = {
      url = "github:jamesbrink/InvokeAI/feature/nix-flake";
    };
    ai-toolkit = {
      url = "github:jamesbrink/ai-toolkit/refactor";
    };
    acris-scrapers = {
      url = "git+ssh://git@github.com/quantierra/acris-scrapers.git";
    };
    zerobyte = {
      url = "github:utensils/zerobyte-nix";
    };
    # zerobyte = {
    #   url = "path:/Users/jamesbrink/Projects/utensils/zerobyte-nix";
    # };
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    why = {
      url = "github:jamesbrink/why";
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
      comfyui-nix,
      invokeai,
      acris-scrapers,
      ai-toolkit,
      zerobyte,
      bun2nix,
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
          (import ./overlays/pixinsight.nix)
          (import ./overlays/gogcli.nix)
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
      pkgsAarch64Darwin = import nixpkgs {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };
      pythonRuntimeDeps = ps: [
        ps.typer
        ps.rich
        ps."tomli-w"
        ps.pyyaml
      ];
      hotkeysBundles = {
        x86_64-linux = import ./lib/hotkeys.nix { inherit pkgs; };
        aarch64-darwin = import ./lib/hotkeys.nix { pkgs = pkgsAarch64Darwin; };
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
          pythonEnv = pkgs.python313.withPackages (
            ps:
            (pythonRuntimeDeps ps)
            ++ [
              ps.pytest
              ps."pytest-mock"
            ]
          );

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
              {
                name = "PATH";
                eval = "$HOME/.local/bin:$PATH";
              }
            ];

            packages = with pkgs; [
              nixfmt
              treefmt
              rsync
              openssh
              bash
              nodePackages.prettier # For JSON and HTML formatting
              nodePackages.markdownlint-cli # Markdown linting
              jq # For JSON processing
              pythonEnv
              ruff
              basedpyright
              python313Packages.pylint
              age # For secrets encryption
              (pkgs.callPackage "${inputs.agenix}/pkgs/agenix.nix" { }) # agenix from flake input
              nixos-anywhere # For initial deployments with disko
              nixos-rebuild-ng # For remote NixOS deployments from Darwin
              nvd # For comparing NixOS generations/closures
              shellcheck # For shell script linting
              trufflehog # For secret scanning
              gitleaks # For git-aware secret scanning
              pre-commit # For git hooks management
              python313Packages.pipx # For installing Python tools like omnara
              bun2nix.packages.${system}.default # For converting bun lockfiles to Nix expressions
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
                help = "Deploy the configuration to a target host (use --build-host <host> for remote build)";
                command = ''$PRJ_ROOT/scripts/deploy.sh "$@"'';
              }

              {
                name = "deploy-test";
                category = "deployment";
                help = "Test the deployment without making changes";
                command = ''$PRJ_ROOT/scripts/deploy-test.sh "$@"'';
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
                  "$PRJ_ROOT/scripts/deploy-all.sh" "$@"
                '';
              }
              {
                name = "deploy-local";
                category = "deployment";
                help = "Build locally and deploy to a remote host (useful for low-RAM targets)";
                command = ''$PRJ_ROOT/scripts/deploy-local.sh "$@"'';
              }

              {
                name = "deploy-k8s";
                category = "deployment";
                help = "Invoke the Kubernetes helper (see ./scripts/deploy-k8s.py --help)";
                command = ''$PRJ_ROOT/scripts/deploy-k8s.py "$@"'';
              }

              {
                name = "deploy-rancher-monitoring";
                category = "deployment";
                help = "Deploy / refresh Rancher + monitoring via deploy-k8s.py";
                command = ''$PRJ_ROOT/scripts/deploy-k8s.py rancher "$@"'';
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
                command = ''$PRJ_ROOT/scripts/health-check.sh "$@"'';
              }

              {
                name = "nix-gc";
                category = "maintenance";
                help = "Run garbage collection to free up disk space";
                command = ''$PRJ_ROOT/scripts/nix-gc.sh "$@"'';
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
                command = ''$PRJ_ROOT/scripts/show-generations.sh "$@"'';
              }

              {
                name = "rollback";
                category = "maintenance";
                help = "Rollback to the previous generation on a host";
                command = ''$PRJ_ROOT/scripts/rollback.sh "$@"'';
              }

              {
                name = "samba-add-user";
                category = "maintenance";
                help = "Add or update a Samba user password";
                command = ''$PRJ_ROOT/scripts/samba-add-user.sh "$@"'';
              }

              {
                name = "secrets-edit";
                category = "secrets";
                help = "Edit a secret file (auto-adds to secrets.nix if new)";
                command = ''$PRJ_ROOT/scripts/secrets-edit.sh "$@"'';
              }

              {
                name = "secrets-add";
                category = "secrets";
                help = "Create a new secret (deprecated: use secrets-edit instead)";
                command = ''$PRJ_ROOT/scripts/secrets-add.sh "$@"'';
              }

              {
                name = "secrets-rekey";
                category = "secrets";
                help = "Re-encrypt all secrets with current recipients";
                command = ''$PRJ_ROOT/scripts/secrets-rekey.sh "$@"'';
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
                command = ''$PRJ_ROOT/scripts/secrets-verify.sh "$@"'';
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
                command = ''$PRJ_ROOT/scripts/secrets-add-host.sh "$@"'';
              }

              # ───────────────────────────────────────────────────────
              # NETBOOT COMMANDS - For netboot infrastructure
              # ───────────────────────────────────────────────────────
              {
                name = "netboot-build";
                category = "netboot";
                help = "Build and deploy N100 netboot images";
                command = ''
                  NIX_CONFIG_DIR="$PRJ_ROOT" "$PRJ_ROOT/scripts/build-netboot-images.sh"
                '';
              }

              {
                name = "netboot-setup-macs";
                category = "netboot";
                help = "Document N100 MAC addresses for netboot";
                command = ''
                  echo "Setting up N100 MAC addresses..."
                  cd "$PRJ_ROOT"
                  ./scripts/setup-n100-macs.sh
                '';
              }

              {
                name = "deploy-n100";
                category = "netboot";
                help = "Initial deployment to N100 node using nixos-anywhere (creates ZFS volumes). Use NIXOS_ANYWHERE_NOCONFIRM=1 to skip confirmation";
                command = ''$PRJ_ROOT/scripts/deploy-n100.sh "$@"'';
              }

              {
                name = "deploy-n100-local";
                category = "netboot";
                help = "Initial deployment to N100 node using nixos-anywhere with local build (for resource-constrained targets)";
                command = ''$PRJ_ROOT/scripts/deploy-n100-local.sh "$@"'';
              }

              {
                name = "secrets-print";
                category = "secrets";
                help = "Decrypt and print a secret (for testing/debugging)";
                command = ''$PRJ_ROOT/scripts/secrets-print.sh "$@"'';
              }

              # ───────────────────────────────────────────────────────
              # SECURITY COMMANDS - For scanning and security checks
              # ───────────────────────────────────────────────────────
              {
                name = "scan-secrets";
                category = "security";
                help = "Scan for secrets in the repository (use --help for options)";
                command = ''$PRJ_ROOT/scripts/scan-secrets.sh "$@"'';
              }

              {
                name = "scan-secrets-history";
                category = "security";
                help = "Deep scan git history for secrets (use --help for options)";
                command = ''$PRJ_ROOT/scripts/scan-secrets-history.sh "$@"'';
              }

              {
                name = "scan-secrets-pre-commit";
                category = "security";
                help = "Pre-commit hook to scan staged files for secrets";
                command = ''$PRJ_ROOT/scripts/scan-secrets-pre-commit.sh "$@"'';
              }

              {
                name = "scan-gitleaks";
                category = "security";
                help = "Scan for secrets using GitLeaks (use --help for options)";
                command = ''$PRJ_ROOT/scripts/scan-gitleaks.sh "$@"'';
              }

              {
                name = "security-audit";
                category = "security";
                help = "Run a full security audit (all scanners)";
                command = ''
                  echo "Running full security audit..."
                  echo
                  echo "1. TruffleHog filesystem scan..."
                  "$PRJ_ROOT/scripts/scan-secrets.sh" --filesystem
                  echo
                  echo "2. TruffleHog history scan..."
                  "$PRJ_ROOT/scripts/scan-secrets-history.sh"
                  echo
                  echo "3. GitLeaks repository scan..."
                  "$PRJ_ROOT/scripts/scan-gitleaks.sh"
                  echo
                  echo "Security audit complete!"
                '';
              }

              {
                name = "pre-commit-install";
                category = "security";
                help = "Install pre-commit hooks for formatting and security";
                command = ''
                  echo "Installing pre-commit hooks..."
                  pre-commit install
                  echo "Pre-commit hooks installed successfully!"
                  echo
                  echo "Hooks will run automatically on git commit."
                  echo "To run manually: pre-commit run --all-files"
                '';
              }

              {
                name = "pre-commit-run";
                category = "security";
                help = "Run all pre-commit hooks manually";
                command = "pre-commit run --all-files";
              }

              # Backup commands
              {
                name = "restic-status";
                category = "backup";
                help = "Check Restic backup status on all hosts";
                command = ''$PRJ_ROOT/scripts/restic-status.sh "$@"'';
              }

              {
                name = "restic-run";
                category = "backup";
                help = "Manually trigger backup on a specific host";
                command = ''$PRJ_ROOT/scripts/restic-run.sh "$@"'';
              }

              {
                name = "restic-snapshots";
                category = "backup";
                help = "List snapshots for a host";
                command = ''RESTIC_PATH="${pkgs.restic}/bin/restic" "$PRJ_ROOT/scripts/restic-snapshots.sh" "$@"'';
              }
            ];
          };
        }
      );

      #########################################################################
      # Packages                                                              #
      #########################################################################

      packages = lib.genAttrs [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          python = pkgs.python311Packages;
          themeLib = import ./modules/themes/lib.nix {
            omarchySrc = inputs.omarchy;
          };
          themeData =
            pkgs.runCommand "themectl-themes.json"
              {
                inherit (themeLib) wallpaperStoreRefs;
                omarchySource = inputs.omarchy;
              }
              ''
                cat > "$out" <<'EOF'
                ${themeLib.themeMetadataJSON}
                EOF
              '';
          themectlPkg = python.buildPythonApplication {
            pname = "themectl";
            version = "0.1.0";
            format = "pyproject";
            src = ./scripts/themectl;
            nativeBuildInputs = [ python."flit-core" ];
            propagatedBuildInputs = pythonRuntimeDeps python;
            nativeCheckInputs = [
              python.pytest
              python."pytest-mock"
            ];
            pythonImportsCheck = [ "themectl" ];
            preBuild = ''
              # Bundle colors from modules/themes/colors/ into themectl package
              mkdir -p themectl/colors
              for color_file in ${./modules/themes/colors}/*.toml; do
                cp "$color_file" themectl/colors/
              done

              # Bundle btop themes from modules/themes/assets/btop/
              mkdir -p themectl/assets/btop
              for btop_file in ${./modules/themes/assets/btop}/*.theme; do
                cp "$btop_file" themectl/assets/btop/
              done
            '';
            checkPhase = ''
              pytest
            '';
          };
        in
        {
          themectl = themectlPkg;
          themectl-theme-data = themeData;
        }
      );

      #########################################################################
      # Checks                                                                #
      #########################################################################

      checks = lib.genAttrs [ "aarch64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          skhdConfigText = self.darwinConfigurations.halcyon.config.services.skhd.skhdConfig;
        in
        {
          skhdHexKeycase =
            pkgs.runCommand "skhd-hex-keycase"
              {
                inherit skhdConfigText;
                passAsFile = [ "skhdConfigText" ];
              }
              ''
                    set -euo pipefail
                if ! grep -Fq 'cmd - 0x1B :' "$skhdConfigTextPath"; then
                  echo "expected uppercase 0x1B chord in workspace focus bindings" >&2
                  exit 1
                fi
                if ! grep -Fq 'cmd + shift - 0x1B :' "$skhdConfigTextPath"; then
                  echo "expected uppercase 0x1B chord in workspace move bindings" >&2
                  exit 1
                fi
                    touch "$out"
              '';
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
            hotkeysBundle = hotkeysBundles."x86_64-linux";
          };

          modules = [
            home-manager.nixosModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
            agenix.nixosModules.default
            disko.nixosModules.disko
            zerobyte.nixosModules.default
            ./hosts/n100-01/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
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
            hotkeysBundle = hotkeysBundles."x86_64-linux";
          };

          modules = [
            home-manager.nixosModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
            agenix.nixosModules.default
            disko.nixosModules.disko
            ./hosts/n100-02/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
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
            hotkeysBundle = hotkeysBundles."x86_64-linux";
          };

          modules = [
            home-manager.nixosModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
            agenix.nixosModules.default
            disko.nixosModules.disko
            ./hosts/n100-03/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
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
            hotkeysBundle = hotkeysBundles."x86_64-linux";
          };

          modules = [
            home-manager.nixosModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
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
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
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
            hotkeysBundle = hotkeysBundles."x86_64-linux";
          };

          modules = [
            home-manager.nixosModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
            agenix.nixosModules.default
            vscode-server.nixosModules.default
            ./modules/vscode-server.nix
            comfyui-nix.nixosModules.default
            ./hosts/alienware/default.nix
            # Use unstable packages
            {
              nixpkgs.overlays = [
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
                comfyui-nix.overlays.default
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
            hotkeysBundle = hotkeysBundles."x86_64-linux";
          };

          modules = [
            home-manager.nixosModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
            agenix.nixosModules.default
            vscode-server.nixosModules.default
            ./modules/vscode-server.nix
            comfyui-nix.nixosModules.default
            invokeai.nixosModules.default
            ai-toolkit.nixosModules.default
            ./hosts/hal9000/default.nix
            zerobyte.nixosModules.default

            # Use unstable packages
            {
              nixpkgs.overlays = [
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
                comfyui-nix.overlays.default
                invokeai.overlays.default
                ai-toolkit.overlays.default
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
            inherit
              inputs
              agenix
              claude-desktop
              comfyui-nix
              acris-scrapers
              ;
            secretsPath = "${inputs.secrets}";
            unstablePkgs = import nixos-unstable {
              system = "aarch64-darwin";
              config.allowUnfree = true;
              overlays = [ ];
            };
            hotkeysBundle = hotkeysBundles."aarch64-darwin";
          };

          modules = [
            home-manager-unstable.darwinModules.home-manager
            ./modules/home-manager/hotkeys-extra-args.nix
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
                (import ./overlays/pixinsight.nix)
                (import ./overlays/gogcli.nix)
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

        bender = darwin.lib.darwinSystem {
          system = "aarch64-darwin"; # M4 Mac Mini

          specialArgs = {
            inherit inputs agenix;
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
                (import ./overlays/gogcli.nix)
                (final: prev: {
                  unstablePkgs = import nixos-unstable {
                    system = "aarch64-darwin";
                    config.allowUnfree = true;
                  };
                })
                invokeai.overlays.default
                ai-toolkit.overlays.default
              ];
            }
            invokeai.darwinModules.default
            ai-toolkit.darwinModules.default
            ./hosts/bender/default.nix
          ];
        };
      };
    };
}
