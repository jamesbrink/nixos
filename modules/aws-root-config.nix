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

  # Determine if we're on Darwin
  isDarwin = pkgs.stdenv.isDarwin;
  rootHome = if isDarwin then "/var/root" else "/root";
  rootGroup = if isDarwin then "wheel" else "root";
in
lib.mkMerge [
  # Common configuration for both Linux and Darwin
  {
    # Configure AWS secrets for root
    age.secrets."root-aws-config" = {
      file = "${effectiveSecretsPath}/jamesbrink/aws/config.age";
      owner = "root";
      group = rootGroup;
      mode = "0600";
    };

    age.secrets."root-aws-credentials" = {
      file = "${effectiveSecretsPath}/jamesbrink/aws/credentials.age";
      owner = "root";
      group = rootGroup;
      mode = "0600";
    };
  }

  # Linux systemd service
  (lib.mkIf (!isDarwin) {
    systemd.services.root-aws-setup = {
      description = "Setup AWS configuration for root";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p ${rootHome}/.aws
        cp ${config.age.secrets."root-aws-config".path} ${rootHome}/.aws/config
        cp ${config.age.secrets."root-aws-credentials".path} ${rootHome}/.aws/credentials
        chmod 700 ${rootHome}/.aws
        chmod 600 ${rootHome}/.aws/config ${rootHome}/.aws/credentials
      '';
    };
  })

  # Darwin activation script
  (lib.mkIf isDarwin {
    system.activationScripts.rootAwsSetup.text = ''
      echo "Setting up AWS configuration for root on Darwin..."
      mkdir -p ${rootHome}/.aws
      cp -f ${config.age.secrets."root-aws-config".path} ${rootHome}/.aws/config
      cp -f ${config.age.secrets."root-aws-credentials".path} ${rootHome}/.aws/credentials
      chmod 700 ${rootHome}/.aws
      chmod 600 ${rootHome}/.aws/config ${rootHome}/.aws/credentials
      chown -R root:${rootGroup} ${rootHome}/.aws
    '';
  })
]
