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
                value = "vim";
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

              # Neovim with Nix language support
              (neovim.override {
                viAlias = true;
                vimAlias = true;
                configure = {
                  customRC = ''
                    " Enable syntax highlighting
                    syntax on
                    filetype plugin indent on

                    " Better defaults
                    set number
                    set relativenumber
                    set expandtab
                    set shiftwidth=2
                    set tabstop=2
                    set smartindent
                    set ignorecase
                    set smartcase
                    set hlsearch
                    set incsearch

                    " Enable mouse support
                    set mouse=a

                    " Better colors for terminal
                    set termguicolors

                    " Nix file type settings
                    autocmd FileType nix setlocal shiftwidth=2 tabstop=2 expandtab
                  '';
                  packages.myVimPackage = with pkgs.vimPlugins; {
                    start = [
                      vim-nix # Nix syntax highlighting
                      nvim-treesitter # Better syntax highlighting
                      vim-sensible # Sensible defaults
                      vim-fugitive # Git integration
                      vim-surround # Surrounding text objects
                      vim-commentary # Easy commenting
                    ];
                  };
                };
              })

              # Nix language server
              nil
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

                  HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
                  SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
                  HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

                  echo "Deploying configuration to $HOST..."

                  # Check if we're on the target host
                  if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
                    echo "Deploying locally to $HOST..."
                    if [ "$SYSTEM" = "darwin" ]; then
                      # macOS deployment - darwin-rebuild requires sudo
                      sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- switch --flake .#$HOST --impure
                    else
                      # NixOS deployment
                      sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake .#$HOST --verbose --impure
                    fi
                  else
                    echo "Deploying remotely to $HOST..."
                    # Check if host is darwin or linux by checking flake configuration
                    if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                      # Darwin host - use regular user
                      # Copy the flake to the remote darwin server and build there
                      rsync -avz --exclude '.git' --exclude 'result' . jamesbrink@$HOST:/tmp/nixos-config/
                      ssh jamesbrink@$HOST "cd /tmp/nixos-config && sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- switch --flake .#$HOST --impure"
                    else
                      # NixOS host - use root
                      # Copy the flake to the remote NixOS server and build there
                      rsync -avz --exclude '.git' --exclude 'result' . root@$HOST:/tmp/nixos-config/
                      ssh root@$HOST "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch --fast --flake .#$HOST --verbose --impure"
                    fi
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

                  HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
                  SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
                  HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

                  echo "Testing deployment to $HOST..."

                  # Check if we're on the target host
                  if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
                    echo "Testing locally on $HOST..."
                    if [ "$SYSTEM" = "darwin" ]; then
                      # macOS dry-run (darwin doesn't have dry-activate)
                      echo "Note: darwin doesn't support dry-activate. Building configuration instead..."
                      NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations.$HOST.system --impure
                    else
                      # NixOS dry-run
                      sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#$HOST --impure
                    fi
                  else
                    echo "Testing remotely on $HOST..."
                    # Check if host is darwin or linux by checking flake configuration
                    if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                      # Darwin host - use regular user
                      # Copy the flake to the remote darwin server and test there
                      rsync -avz --exclude '.git' --exclude 'result' . jamesbrink@$HOST:/tmp/nixos-config/
                      echo "Note: darwin doesn't support dry-activate. Building configuration instead..."
                      ssh jamesbrink@$HOST "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nix build .#darwinConfigurations.$HOST.system --impure"
                    else
                      # NixOS host - use root
                      # Copy the flake to the remote NixOS server and test there
                      rsync -avz --exclude '.git' --exclude 'result' . root@$HOST:/tmp/nixos-config/
                      ssh root@$HOST "cd /tmp/nixos-config && NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild dry-activate --flake .#$HOST --impure"
                    fi
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

                  HOSTNAME=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
                  HOST_LOWER=$(echo "$HOST" | tr '[:upper:]' '[:lower:]')

                  # Check if we're trying to deploy to ourselves
                  if [ "$HOSTNAME" = "$HOST_LOWER" ]; then
                    echo "Error: deploy-local is for remote hosts only. Use 'deploy' for local deployment."
                    exit 1
                  fi

                  # Check if host is Darwin or NixOS
                  if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                    # Darwin deployment
                    echo "Building darwin configuration for $HOST locally..."
                    NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#darwinConfigurations.$HOST.system
                    if [ $? -ne 0 ]; then
                      echo "Build failed! Aborting deployment."
                      exit 1
                    fi
                    
                    echo "Build complete! Copying closure to $HOST..."
                    nix-copy-closure --to jamesbrink@$HOST ./result
                    
                    if [ $? -ne 0 ]; then
                      echo "Failed to copy closure to $HOST! Aborting deployment."
                      exit 1
                    fi
                    
                    echo "Switching to new configuration on $HOST..."
                    STORE_PATH=$(readlink -f ./result)
                    ssh jamesbrink@$HOST "sudo $STORE_PATH/sw/bin/darwin-rebuild switch --flake .#$HOST"
                    
                    if [ $? -eq 0 ]; then
                      echo "Deployment to $HOST complete!"
                    else
                      echo "Failed to switch configuration on $HOST!"
                      exit 1
                    fi
                  else
                    # NixOS deployment
                    # Check if we already have a build result
                    if [ -L ./result ] && [ -e ./result ]; then
                      # Verify this result is for the correct host (macOS-compatible grep)
                      RESULT_HOST=$(readlink ./result | sed -n 's/.*nixos-system-\([^-]*\).*/\1/p' || echo "unknown")
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
                    # Check if host is darwin or linux by checking flake configuration
                    if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                      # Darwin host - use regular user with sudo where needed
                      echo "\nDisk usage on $HOST:"
                      ssh jamesbrink@$HOST "df -h | grep -v tmpfs"
                      echo "\nMemory usage on $HOST:"
                      ssh jamesbrink@$HOST "vm_stat | perl -ne '/page size of (\d+)/ and \$size=\$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf(\"%-20s %8.2f GB\\n\", \"\$1:\", \$2 * \$size / 1073741824);'"
                      echo "\nSystem load on $HOST:"
                      ssh jamesbrink@$HOST "uptime"
                      echo "\nSystem services on $HOST:"
                      ssh jamesbrink@$HOST "sudo launchctl list | grep -E '(com.apple|org.nixos)' | head -20"
                    else
                      # NixOS host - use root
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
                  fi

                  echo "\nHealth check for $HOST complete."
                '';
              }

              {
                name = "nix-gc";
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
                    echo "Usage: nix-gc <hostname>"
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
                    # Check if host is darwin or linux by checking flake configuration
                    if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                      # Darwin host - use regular user with sudo
                      ssh jamesbrink@$HOST "sudo nix-collect-garbage -d"
                    else
                      # NixOS host - use root
                      ssh root@$HOST "nix-collect-garbage -d"
                    fi
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
                    echo "System generations on $HOST:"
                    sudo nix-env -p /nix/var/nix/profiles/system --list-generations
                  else
                    # Remote generations
                    # Check if host is darwin or linux by checking flake configuration
                    if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                      # Darwin host - use regular user with sudo
                      echo "Darwin generations on $HOST:"
                      ssh jamesbrink@$HOST "sudo nix-env -p /nix/var/nix/profiles/system --list-generations"
                    else
                      # NixOS host - use root
                      echo "NixOS generations on $HOST:"
                      ssh root@$HOST "nix-env -p /nix/var/nix/profiles/system --list-generations"
                    fi
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
                    SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
                    if [ "$SYSTEM" = "darwin" ]; then
                      # macOS rollback
                      sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- --rollback switch --impure
                    else
                      # NixOS rollback
                      sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild --rollback switch --impure
                    fi
                  else
                    # Remote rollback
                    # Check if host is darwin or linux by checking flake configuration
                    if nix eval --json .#darwinConfigurations.$HOST._type 2>/dev/null >/dev/null; then
                      # Darwin host - use regular user with sudo
                      ssh jamesbrink@$HOST "sudo NIXPKGS_ALLOW_UNFREE=1 nix run nix-darwin -- --rollback switch --impure"
                    else
                      # NixOS host - use root
                      ssh root@$HOST "NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild --rollback switch --impure"
                    fi
                  fi

                  echo "Rollback on $HOST complete!"
                '';
              }

              {
                name = "secrets-edit";
                category = "secrets";
                help = "Edit a secret file";
                command = ''
                  if [ $# -eq 0 ]; then
                    echo "Error: You must specify a secret file to edit."
                    echo "Usage: secrets-edit <secret-name>"
                    echo "Example: secrets-edit global/claude-desktop-config"
                    echo "         secrets-edit hal9000/syncthing-password"
                    echo ""
                    echo "Note: Do NOT include the 'secrets/' prefix"
                    exit 1
                  fi

                  SECRET_PATH="$1"

                  # Remove 'secrets/' prefix if present 
                  SECRET_PATH="''${SECRET_PATH#secrets/}"

                  # Remove '.age' suffix if present
                  SECRET_PATH="''${SECRET_PATH%.age}"

                  # The actual file path
                  SECRET_FILE="secrets/$SECRET_PATH.age"

                  # Change to secrets directory for proper path resolution
                  cd secrets

                  if [ ! -f "$SECRET_FILE" ]; then
                    echo "Creating new secret: $SECRET_FILE"
                    mkdir -p "$(dirname "$SECRET_FILE")"
                  fi

                  # Use proper agenix syntax - use ed25519 by default
                  if [ -f ~/.ssh/id_ed25519 ]; then
                    IDENTITY_FILE=~/.ssh/id_ed25519
                  elif [ -f ~/.ssh/id_rsa ]; then
                    IDENTITY_FILE=~/.ssh/id_rsa
                  else
                    echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
                    exit 1
                  fi

                  RULES=./secrets.nix EDITOR="''${EDITOR:-vim}" agenix -e "$SECRET_FILE" -i "$IDENTITY_FILE"
                  cd ..
                '';
              }

              {
                name = "secrets-rekey";
                category = "secrets";
                help = "Re-encrypt all secrets with current recipients";
                command = ''
                  echo "Re-encrypting all secrets..."
                  cd secrets

                  # Use id_ed25519 by default, fall back to id_rsa
                  if [ -f ~/.ssh/id_ed25519 ]; then
                    IDENTITY_FILE=~/.ssh/id_ed25519
                  elif [ -f ~/.ssh/id_rsa ]; then
                    IDENTITY_FILE=~/.ssh/id_rsa
                  else
                    echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
                    exit 1
                  fi

                  RULES=./secrets.nix agenix -r -i "$IDENTITY_FILE"
                  cd ..
                  echo "All secrets have been re-encrypted"
                '';
              }

              {
                name = "secrets-list";
                category = "secrets";
                help = "List all secret files";
                command = ''
                  echo "Available secrets:"
                  find secrets/secrets -name "*.age" -type f | sort | sed 's|^secrets/||; s|\.age$||'
                '';
              }

              {
                name = "secrets-verify";
                category = "secrets";
                help = "Verify all secrets can be decrypted";
                command = ''
                  echo "Verifying all secrets..."
                  FAILED=0

                  # Use id_ed25519 by default, fall back to id_rsa
                  if [ -f ~/.ssh/id_ed25519 ]; then
                    IDENTITY_FILE=~/.ssh/id_ed25519
                  elif [ -f ~/.ssh/id_rsa ]; then
                    IDENTITY_FILE=~/.ssh/id_rsa
                  else
                    echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
                    exit 1
                  fi

                  for secret in $(find secrets/secrets -name "*.age" -type f | sort); do
                    echo -n "Checking $secret... "
                    # Extract the path relative to secrets/secrets/
                    SECRET_PATH="''${secret#secrets/secrets/}"
                    SECRET_PATH="''${SECRET_PATH%.age}"
                    
                    # We need to cd into secrets directory because agenix expects paths relative to rules file
                    if (cd secrets && RULES=./secrets.nix agenix -d "secrets/$SECRET_PATH.age" -i "$IDENTITY_FILE" > /dev/null 2>&1); then
                      echo "✓"
                    else
                      echo "✗ FAILED"
                      FAILED=$((FAILED + 1))
                    fi
                  done

                  if [ $FAILED -eq 0 ]; then
                    echo "All secrets verified successfully!"
                  else
                    echo "WARNING: $FAILED secrets failed verification"
                    exit 1
                  fi
                '';
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
                command = ''
                  if [ $# -eq 0 ]; then
                    echo "Error: You must specify a hostname."
                    echo "Usage: secrets-add-host <hostname>"
                    exit 1
                  fi

                  HOST="$1"
                  echo "Getting SSH host key for $HOST..."

                  # Try to get the host key
                  KEY=$(ssh-keyscan -t ed25519 "$HOST" 2>/dev/null | grep -v "^#" | head -1)

                  if [ -z "$KEY" ]; then
                    echo "Error: Could not retrieve SSH key for $HOST"
                    exit 1
                  fi

                  echo "Found key: $KEY"
                  echo ""
                  echo "Add this to secrets/secrets.nix in the host keys section:"
                  echo "  $HOST = \"$(echo "$KEY" | cut -d' ' -f2-3)\";"
                  echo ""
                  echo "Then run 'secrets-rekey' to re-encrypt all secrets"
                '';
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
                command = ''
                  if [ $# -eq 0 ]; then
                    echo "Error: You must specify an N100 hostname."
                    echo "Usage: deploy-n100 <n100-hostname>"
                    echo "Available N100 hosts: n100-01, n100-02, n100-03, n100-04"
                    echo ""
                    echo "This command performs initial deployment including:"
                    echo "  - Creating ZFS volumes with disko"
                    echo "  - Installing NixOS configuration"
                    echo "  - Setting up encrypted secrets"
                    echo ""
                    echo "Prerequisites:"
                    echo "  - N100 node must be booted into netboot installer"
                    echo "  - SSH access to root@nixos-installer must be available"
                    echo ""
                    echo "Environment variables:"
                    echo "  NIXOS_ANYWHERE_NOCONFIRM=1  Skip confirmation prompt"
                    echo "  TARGET_HOST_OVERRIDE=<ip>   Override target host IP/hostname"
                    echo ""
                    echo "Examples:"
                    echo "  deploy-n100 n100-04"
                    echo "  NIXOS_ANYWHERE_NOCONFIRM=1 deploy-n100 n100-04"
                    echo "  TARGET_HOST_OVERRIDE=10.70.100.204 deploy-n100 n100-04"
                    exit 1
                  fi

                  HOST="$1"

                  # Validate it's an N100 host
                  if ! echo "$HOST" | grep -q "^n100-0[1-4]$"; then
                    echo "Error: Invalid N100 hostname. Must be n100-01, n100-02, n100-03, or n100-04"
                    exit 1
                  fi

                  # Try to determine the target host
                  TARGET_HOST=""

                  # First try the hostname directly (in case it has the right IP)
                  echo "Checking if $HOST is running the installer..."
                  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$HOST" "test -f /etc/is-installer" 2>/dev/null; then
                    TARGET_HOST="$HOST"
                    echo "Found installer at $HOST"
                  # Then try nixos-installer
                  elif ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@nixos-installer "test -f /etc/is-installer" 2>/dev/null; then
                    TARGET_HOST="nixos-installer"
                    echo "Found installer at nixos-installer"
                  else
                    echo "Error: Cannot reach installer. Make sure:"
                    echo "  1. N100 node is booted into netboot installer"
                    echo "  2. You can SSH to either root@$HOST or root@nixos-installer"
                    echo ""
                    echo "If the installer is at a different IP, you can specify it:"
                    echo "  TARGET_HOST=<ip-address> deploy-n100 $HOST"
                    exit 1
                  fi

                  # Allow override via environment variable
                  if [ -n "''${TARGET_HOST_OVERRIDE:-}" ]; then
                    TARGET_HOST="$TARGET_HOST_OVERRIDE"
                    echo "Using override target: $TARGET_HOST"
                  fi

                  echo "Starting initial deployment to $HOST..."
                  echo "This will:"
                  echo "  - Create ZFS volumes according to disko configuration"
                  echo "  - Install NixOS configuration"
                  echo "  - Configure encrypted secrets"
                  echo ""

                  # Check if we're in non-interactive mode or auto-confirm
                  if [ "''${NIXOS_ANYWHERE_NOCONFIRM:-}" = "1" ] || [ "''${CI:-}" = "true" ]; then
                    echo "Auto-confirming deployment (NIXOS_ANYWHERE_NOCONFIRM=1 or CI=true)"
                  else
                    read -p "Continue? (y/N) " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                      echo "Deployment cancelled."
                      exit 0
                    fi
                  fi

                  # Run nixos-anywhere
                  echo "Running nixos-anywhere..."
                  echo "Target: root@$TARGET_HOST"
                  echo "Configuration: $HOST"
                  echo ""

                  NIXPKGS_ALLOW_UNFREE=1 nixos-anywhere \
                    --impure \
                    --flake ".#$HOST" \
                    --target-host "root@$TARGET_HOST" \
                    --build-on-remote \
                    --option experimental-features "nix-command flakes" \
                    --print-build-logs

                  if [ $? -eq 0 ]; then
                    echo ""
                    echo "Initial deployment to $HOST complete!"
                    echo "The system should reboot into the installed NixOS."
                    echo ""
                    echo "Next steps:"
                    echo "  1. Wait for the system to reboot"
                    echo "  2. SSH to root@$HOST"
                    echo "  3. Run further deployments with: deploy $HOST"
                  else
                    echo ""
                    echo "Deployment failed! Check the error messages above."
                    exit 1
                  fi
                '';
              }

              {
                name = "deploy-n100-local";
                category = "netboot";
                help = "Initial deployment to N100 node using nixos-anywhere with local build (for resource-constrained targets)";
                command = ''
                  if [ $# -eq 0 ]; then
                    echo "Error: You must specify an N100 hostname."
                    echo "Usage: deploy-n100-local <n100-hostname>"
                    echo "Available N100 hosts: n100-01, n100-02, n100-03, n100-04"
                    echo ""
                    echo "This command performs initial deployment with local building including:"
                    echo "  - Building the configuration locally (not on the N100)"
                    echo "  - Creating ZFS volumes with disko"
                    echo "  - Installing NixOS configuration"
                    echo "  - Setting up encrypted secrets"
                    echo ""
                    echo "Prerequisites:"
                    echo "  - N100 node must be booted into netboot installer"
                    echo "  - SSH access to root@nixos-installer must be available"
                    echo ""
                    echo "Environment variables:"
                    echo "  NIXOS_ANYWHERE_NOCONFIRM=1  Skip confirmation prompt"
                    echo "  TARGET_HOST_OVERRIDE=<ip>   Override target host IP/hostname"
                    exit 1
                  fi

                  HOST="$1"

                  # Validate it's an N100 host
                  if ! echo "$HOST" | grep -q "^n100-0[1-4]$"; then
                    echo "Error: Invalid N100 hostname. Must be n100-01, n100-02, n100-03, or n100-04"
                    exit 1
                  fi

                  # Try to determine the target host
                  TARGET_HOST=""

                  # First try the hostname directly (in case it has the right IP)
                  echo "Checking if $HOST is running the installer..."
                  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$HOST" "test -f /etc/is-installer" 2>/dev/null; then
                    TARGET_HOST="$HOST"
                    echo "Found installer at $HOST"
                  # Then try nixos-installer
                  elif ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@nixos-installer "test -f /etc/is-installer" 2>/dev/null; then
                    TARGET_HOST="nixos-installer"
                    echo "Found installer at nixos-installer"
                  else
                    echo "Error: Cannot reach installer. Make sure:"
                    echo "  1. N100 node is booted into netboot installer"
                    echo "  2. You can SSH to either root@$HOST or root@nixos-installer"
                    echo ""
                    echo "If the installer is at a different IP, you can specify it:"
                    echo "  TARGET_HOST_OVERRIDE=<ip-address> deploy-n100-local $HOST"
                    exit 1
                  fi

                  # Allow override via environment variable
                  if [ -n "''${TARGET_HOST_OVERRIDE:-}" ]; then
                    TARGET_HOST="$TARGET_HOST_OVERRIDE"
                    echo "Using override target: $TARGET_HOST"
                  fi

                  echo "Starting initial deployment to $HOST with local build..."
                  echo "This will:"
                  echo "  - Build the configuration locally"
                  echo "  - Create ZFS volumes according to disko configuration"
                  echo "  - Install NixOS configuration"
                  echo "  - Configure encrypted secrets"
                  echo ""

                  # Check if we're in non-interactive mode or auto-confirm
                  if [ "''${NIXOS_ANYWHERE_NOCONFIRM:-}" = "1" ] || [ "''${CI:-}" = "true" ]; then
                    echo "Auto-confirming deployment (NIXOS_ANYWHERE_NOCONFIRM=1 or CI=true)"
                  else
                    read -p "Continue? (y/N) " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                      echo "Deployment cancelled."
                      exit 0
                    fi
                  fi

                  # Run nixos-anywhere with local build
                  echo "Running nixos-anywhere with local build..."
                  echo "Target: root@$TARGET_HOST"
                  echo "Configuration: $HOST"
                  echo ""

                  NIXPKGS_ALLOW_UNFREE=1 nixos-anywhere \
                    --impure \
                    --flake ".#$HOST" \
                    --target-host "root@$TARGET_HOST" \
                    --option experimental-features "nix-command flakes" \
                    --print-build-logs

                  if [ $? -eq 0 ]; then
                    echo ""
                    echo "Initial deployment to $HOST complete!"
                    echo "The system should reboot into the installed NixOS."
                    echo ""
                    echo "Next steps:"
                    echo "  1. Wait for the system to reboot"
                    echo "  2. SSH to root@$HOST"
                    echo "  3. Run further deployments with: deploy-local $HOST"
                  else
                    echo ""
                    echo "Deployment failed! Check the error messages above."
                    exit 1
                  fi
                '';
              }

              {
                name = "secrets-print";
                category = "secrets";
                help = "Decrypt and print a secret (for testing/debugging)";
                command = ''
                  if [ $# -eq 0 ]; then
                    echo "Error: You must specify a secret file to print."
                    echo "Usage: secrets-print <secret-name>"
                    echo "Example: secrets-print global/claude-desktop-config"
                    echo "         secrets-print hal9000/syncthing-password"
                    echo ""
                    echo "Available secrets:"
                    find secrets/secrets -name "*.age" -type f | sort | sed 's|^secrets/||; s|\.age$||'
                    exit 1
                  fi

                  SECRET_PATH="$1"

                  # Remove 'secrets/' prefix if present 
                  SECRET_PATH="''${SECRET_PATH#secrets/}"

                  # Remove '.age' suffix if present
                  SECRET_PATH="''${SECRET_PATH%.age}"

                  # The actual file path
                  SECRET_FILE="secrets/secrets/$SECRET_PATH.age"

                  if [ ! -f "$SECRET_FILE" ]; then
                    echo "Error: Secret file not found: $SECRET_PATH"
                    echo ""
                    echo "Available secrets:"
                    find secrets/secrets -name "*.age" -type f | sort | sed 's|^secrets/||; s|\.age$||'
                    exit 1
                  fi

                  # Check for identity file
                  IDENTITY_FILE=""
                  if [ -f ~/.ssh/id_ed25519 ]; then
                    IDENTITY_FILE="$HOME/.ssh/id_ed25519"
                  elif [ -f ~/.ssh/id_rsa ]; then
                    IDENTITY_FILE="$HOME/.ssh/id_rsa"
                  else
                    echo "Error: No SSH identity file found (~/.ssh/id_ed25519 or ~/.ssh/id_rsa)"
                    exit 1
                  fi

                  echo "Decrypting $SECRET_FILE..."
                  echo "────────────────────────────────────────────────────────"

                  # Decrypt and capture output
                  # We need to cd into secrets directory because agenix expects paths relative to rules file
                  DECRYPTED_CONTENT=$(cd secrets && RULES=./secrets.nix agenix -d "secrets/$SECRET_PATH.age" -i "$IDENTITY_FILE" 2>&1)
                  DECRYPT_STATUS=$?

                  if [ $DECRYPT_STATUS -eq 0 ]; then
                    echo "$DECRYPTED_CONTENT"
                    echo "────────────────────────────────────────────────────────"
                    echo "Secret decrypted successfully!"
                  else
                    echo "────────────────────────────────────────────────────────"
                    echo "Error: Failed to decrypt secret. Make sure you have access to this secret."
                    echo "This usually means your SSH key is not listed as a recipient for this secret."
                    echo ""
                    echo "Error details: $DECRYPTED_CONTENT"
                    exit 1
                  fi
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
      };
    };
}
