{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # 1. System Utilities
    at
    bzip2
    direnv
    fd
    hdparm
    htop
    neofetch
    parted
    rsync
    screen
    tmux
    unzip

    # 2. Network Tools
    dig
    dnsutils
    httpie
    iperf2
    ipmitool
    netcat
    nfs-utils
    speedtest-cli
    wget
    wireguard-tools

    # 3. Development Tools
    git
    jq
    nixpkgs-fmt
    python3
    python311Packages.boto3
    python311Packages.pip
    python312Packages.pynvim

    # 4. Package Management
    cachix
    home-manager

    # 5. Text Editors
    neovim
    vim

    # 6. Shell Tools
    lf
    thefuck
    zsh

    # 7. Security
    bitwarden-cli
    openssh
  ];
}
