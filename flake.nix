{
  description = "NixOS System Configurations";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-24.05";
    };
    nixos-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixos-unstable";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    secrets = {
      url = "git+ssh://git@github.com/jamesbrink/nix-secrets.git";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-unstable, home-manager, home-manager-stable, agenix, secrets, ... }@inputs: {
    nixosConfigurations = {
      n100-01 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs agenix;
          secretsPath = "${inputs.secrets}";
        };

        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default
          ./hosts/n100-01/default.nix
        ];
      };

      n100-03 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs agenix;
          secretsPath = "${inputs.secrets}";
        };

        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default
          ./hosts/n100-03/default.nix
        ];
      };

      # New HAL9000 configuration using stable branch
      HAL9000 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs agenix;
          secretsPath = "${inputs.secrets}";
        };

        modules = [
          home-manager-stable.nixosModules.home-manager
          agenix.nixosModules.default
          ./hosts/HAL9000/default.nix

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
