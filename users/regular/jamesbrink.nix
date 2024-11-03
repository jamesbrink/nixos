{ config, pkgs, ... }:

{
  # 1. User Account Configuration
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

  # 2. Home Manager Configuration
  home-manager.users.jamesbrink = { pkgs, ... }: {
    # Shell and Terminal
    programs = {
      # Starship Prompt
      starship = {
        enable = true;
      };

      # ZSH Configuration
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

    # Home Manager State Version
    home.stateVersion = "24.05";
  };

  # 3. Security Configuration
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

  # 4. Age Secrets Configuration
  age.identityPaths = [
    "/home/jamesbrink/.ssh/id_ed25519"
  ];

  # 5. Services Configuration
  services.syncthing = {
    enable = true;
    user = "jamesbrink";
    dataDir = "/home/jamesbrink/";
    configDir = "/home/jamesbrink/.config/syncthing";
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "0.0.0.0:8384";

    settings = {
      # GUI Settings
      gui = {
        user = "jamesbrink";
        password = "password";
      };

      # Device Configuration
      devices = {
        "DarkStarMk6Mod1" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/DarkStarMk6Mod1-id.age".file;
        };
        "Alienware15R4" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/Alienware15R4-id.age".file;
        };
        "N100-01" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/N100-01-id.age".file;
        };
        "N100-02" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/N100-02-id.age".file;
        };
        "N100-03" = {
          autoAcceptFolders = true;
          id = toString config.age.secrets."secrets/global/syncthing/N100-03-id.age".file;
        };
      };

      # Folder Configuration
      folders = {
        "Projects" = {
          path = "/home/jamesbrink/Projects";
          devices = [ "DarkStarMk6Mod1" "Alienware15R4" "N100-01" "N100-02" "N100-03" ];
          label = "Projects";
          enable = false;
        };
        "Documents" = {
          path = "/home/jamesbrink/Documents";
          devices = [ "DarkStarMk6Mod1" "Alienware15R4" "N100-01" "N100-02" "N100-03" ];
          label = "Documents";
          enable = false;
        };
      };
    };
  };
}
