# Bender - OpenClaw agent user for N100 cluster
{
  config,
  pkgs,
  lib,
  secretsPath ? null,
  ...
}:

let
  effectiveSecretsPath =
    if secretsPath != null then
      secretsPath
    else if (config._module.args.secretsPath or null) != null then
      config._module.args.secretsPath
    else
      "./secrets";
in
{
  # Linux user configuration
  users.users.bender = {
    isNormalUser = true;
    uid = 1001;
    description = "Bender - OpenClaw Agent";
    createHome = true;
    hashedPasswordFile = config.age.secrets."bender-hashed-password".path;
    extraGroups = [
      "docker"
      "wheel"
      "input"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # Bender's SSH key from bender.local
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmcoMbMstPPKsGH0oQLv8N6WgDSt8jvqcXpPfNkzAMq jamesbrink@bender.local"
    ];
  };

  # Passwordless sudo for bender
  security.sudo.extraRules = [
    {
      users = [ "bender" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Age secret for bender's password
  age.secrets."bender-hashed-password" = {
    file = "${effectiveSecretsPath}/bender/hashed-password.age";
    owner = "root";
    group = "root";
    mode = "0600";
  };
}
