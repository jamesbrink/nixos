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
      url = "github:nix-community/home-manager/release-24.05";
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
  };

  outputs = { self, nixpkgs, nixos-unstable, home-manager, home-manager-unstable, agenix, secrets, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
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

        hal9000 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix self;
            secretsPath = "${inputs.secrets}";
          };

          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
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
      };

      # packages.${system} = {
      #   ollama-cuda = pkgs.callPackage ./modules/packages/ollama {};
      # };
    };
}
