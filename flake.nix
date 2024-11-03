{
  # 1. Basic Flake Information
  description = "NixOS configuration";

  # 2. Input Definitions
  inputs = {
    # Core Inputs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # System Management
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets Management
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/jamesbrink/nix-secrets.git";
      flake = false;
    };
  };

  # 3. Output Definitions
  outputs = { self, nixpkgs, home-manager, agenix, secrets, ... }@inputs: {
    # NixOS System Configurations
    nixosConfigurations = {
      n100-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        # Special Arguments
        specialArgs = {
          inherit inputs agenix;
          secretsPath = "${inputs.secrets}";
        };

        # System Modules
        modules = [
          # Core Modules
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default

          # Host Configuration
          ./hosts/n100-01/default.nix
        ];
      };
    };
  };
}
