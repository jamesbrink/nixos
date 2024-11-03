{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
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

  outputs = { self, nixpkgs, home-manager, agenix, secrets, ... }@inputs: {
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
    };
  };
}
