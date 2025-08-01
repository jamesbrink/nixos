# Module to configure AWS CLI for root user on all hosts
{
  config,
  lib,
  pkgs,
  secretsPath ? ./secrets,
  ...
}:

let
  # Handle secretsPath resolution
  effectiveSecretsPath =
    if builtins.isString secretsPath then
      secretsPath
    else if config ? _module.args.secretsPath then
      config._module.args.secretsPath
    else
      "./secrets";
in
# Only configure on Linux systems
lib.mkIf (!pkgs.stdenv.isDarwin) {
  # Configure AWS secrets for root
  age.secrets."root-aws-config" = {
    file = "${effectiveSecretsPath}/jamesbrink/aws/config.age";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  age.secrets."root-aws-credentials" = {
    file = "${effectiveSecretsPath}/jamesbrink/aws/credentials.age";
    owner = "root";
    group = "root";
    mode = "0600";
  };

  # Linux systemd service
  systemd.services.root-aws-setup = {
    description = "Setup AWS configuration for root";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /root/.aws
      cp ${config.age.secrets."root-aws-config".path} /root/.aws/config
      cp ${config.age.secrets."root-aws-credentials".path} /root/.aws/credentials
      chmod 700 /root/.aws
      chmod 600 /root/.aws/config /root/.aws/credentials
    '';
  };
}
