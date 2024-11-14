{ config, pkgs, ... }:

{
  users.users.jamesbrink = {
    isNormalUser = true;
    description = "James Brink";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "qemu-libvirtd"
      "libvirtd"
      "incus-admin"
    ];
    shell = pkgs.zsh;
    useDefaultShell = true;
    packages = with pkgs; [ ];
  };

  home-manager.users.jamesbrink = { pkgs, ... }: {
    programs = {
      starship = {
        enable = true;
      };

      zsh = {
        enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        oh-my-zsh = {
          enable = true;
          plugins = [ "git" "thefuck" ];
          theme = "robbyrussell";
        };

        shellAliases = {
          ll = "ls -l";
          update = "sudo nixos-rebuild switch --flake /etc/nixos/#default";
          cleanup = "sudo nix-collect-garbage -d";
        };

        history.size = 100000;
      };
    };

    home.stateVersion = "24.05";
  };

  security.sudo.extraRules = [
    {
      users = [ "jamesbrink" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  age.identityPaths = [
    "/home/jamesbrink/.ssh/id_ed25519"
  ];

  services.syncthing = {
    enable = true;
    user = "jamesbrink";
    dataDir = "/home/jamesbrink/";
    configDir = "/home/jamesbrink/.config/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "0.0.0.0:8384";

    settings = {
      gui = {
        user = "jamesbrink";
        password = "password";
      };

      devices = {
        "darkstarmk6mod1" = {
          autoAcceptFolders = true;
          id = config.age.secrets."secrets/global/syncthing/darkstarmk6mod1-id.age".path;
        };
        "alienware15r4" = {
          autoAcceptFolders = true;
          id = config.age.secrets."secrets/global/syncthing/alienware15r4-id.age".path;
        };
        "n100-01" = {
          autoAcceptFolders = true;
          id = config.age.secrets."secrets/global/syncthing/n100-01-id.age".path;
        };
        "n100-02" = {
          autoAcceptFolders = true;
          id = config.age.secrets."secrets/global/syncthing/n100-02-id.age".path;
        };
        "n100-03" = {
          autoAcceptFolders = true;
          id = config.age.secrets."secrets/global/syncthing/n100-03-id.age".path;
        };
        "hal9000" = {
          autoAcceptFolders = true;
          id = config.age.secrets."secrets/global/syncthing/hal9000-id.age".path;
        };
      };

      folders = {
        "Projects" = {
          path = "/home/jamesbrink/Projects";
          devices = [ "darkstarmk6mod1" "alienware15r4" "n100-01" "n100-02" "n100-03" "hal9000" ];
          label = "Projects";
          enable = false;
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [ "darkstarmk6mod1" "alienware15r4" "n100-01" "n100-02" "n100-03" "hal9000" ];
          label = "Documents";
          enable = false;
        };
      };
    };
  };
}
