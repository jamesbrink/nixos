# Darwin-specific user configuration
{
  config,
  pkgs,
  lib,
  inputs,
  secretsPath,
  ...
}:

let
  unstable = pkgs.unstablePkgs;
in
{
  imports = [
    ./jamesbrink-shared.nix
  ];

  # Darwin user configuration
  users.users.jamesbrink = {
    name = "jamesbrink";
    home = "/Users/jamesbrink";
    shell = pkgs.zsh;
  };

  # User packages
  home-manager.users.jamesbrink =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # Common packages for darwin
        atuin
        ffmpeg-full
        imagemagick
        nushell
        pay-respects
        tldr
        xonsh
        yt-dlp

        # Darwin-specific CLI tools
        unstable.aider-chat
        unstable.code2prompt
        unstable.llm
      ];
    };

  # Age configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/Users/jamesbrink/.ssh/id_ed25519"
  ];

  age.secrets."aws-config" = {
    file = "${secretsPath}/secrets/jamesbrink/aws/config.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };

  age.secrets."aws-credentials" = {
    file = "${secretsPath}/secrets/jamesbrink/aws/credentials.age";
    owner = "jamesbrink";
    group = "staff";
    mode = "0600";
  };
}
