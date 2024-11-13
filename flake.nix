{
  description = "NixOS System Configurations";

  inputs = {
    # Use nixos-24.05 for HAL9000
    nixos-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    # Keep existing unstable for other hosts
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixos-stable";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/jamesbrink/nix-secrets.git";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixos-stable, home-manager, home-manager-stable, agenix, secrets, ... }@inputs: {
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
      HAL9000 = nixos-stable.lib.nixosSystem {
        system = "x86_64-linux";

        specialArgs = {
          inherit inputs agenix;
          secretsPath = "${inputs.secrets}";
        };

        modules = [
          home-manager-stable.nixosModules.home-manager
          agenix.nixosModules.default
          ./hosts/HAL9000/default.nix
        ];
      };
    };
  };
}
