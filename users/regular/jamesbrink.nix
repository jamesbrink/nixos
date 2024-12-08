{ config, pkgs, ... }:

{
  users.users.jamesbrink = {
    isNormalUser = true;
    description = "James Brink";
    extraGroups = [
      "docker"
      "incus-admin"
      "kvm"
      "libvirtd"
      "networkmanager"
      "qemu-libvirtd"
      "wheel"
      "input"
    ];
    shell = pkgs.zsh;
    useDefaultShell = true;
    packages = with pkgs; [ ];
  };

  home-manager.users.jamesbrink = { pkgs, config, lib, ... }: {
    home.file."/home/jamesbrink/.ssh/config_external" = {
      source = .ssh/config_external;
    };
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
      ssh = {
        enable = true;
        controlMaster = "auto";
        includes = [
          "/home/jamesbrink/.ssh/config_external"
        ];
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
          id = "A46R3HQ-AW3ODFH-RVOAW4C-P6VFHO5-KHIBRP2-PQLRKIE-YAZTGQO-7QGPCAF";
        };
        "alienware15r4" = {
          id = "LQKOQMG-AIDPDJU-AICPMA4-UPLKWUP-PTWHUNL-IRNJIWD-GY2VU3Q-JLMG6QB";
          autoAcceptFolders = true;
        };
        "n100-01" = {
          autoAcceptFolders = true;
          id = "HCRYHXP-QXLM4FW-SIPYBNL-IOLODXZ-PM5FX7W-3DOQ4ED-GJ5YNSK-LVUJQAA";
        };
        "n100-02" = {
          autoAcceptFolders = true;
          id = "KICZH4D-WJIVHZM-EW2CN5A-WEF44ZA-VAXR7MY-AWTQOXC-APLRSQP-TQCOBQX";
        };
        "n100-03" = {
          autoAcceptFolders = true;
          id = "WYTVEJT-WTMRX73-N3ASBH2-AAHMD5R-N3FUI3M-XXYQAVH-O6GDDU4-LUQVHAT";
        };
        "hal9000" = {
          autoAcceptFolders = true;
          id = "PRCPMWC-H6VGK4G-6X2QQDH-P6UOLJJ-JTLDNYW-LIKBC5X-6WM4T2R-Q5TZEAR";
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
