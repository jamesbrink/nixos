{
  description = "NixOS System Configurations";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-24.11";
    };
    nixos-unstable = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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

        alienware = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          specialArgs = {
            inherit inputs agenix;
            secretsPath = "${inputs.secrets}";
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
      };

      # packages.${system} = {
      #   ollama-cuda = pkgs.callPackage ./modules/packages/ollama {};
      # };
    };
}
