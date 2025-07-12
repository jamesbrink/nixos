{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.heroku-cli;
in
{
  options.services.heroku-cli = {
    enable = mkEnableOption "Heroku CLI with automatic authentication";

    user = mkOption {
      type = types.str;
      default = "jamesbrink";
      description = "User to configure Heroku CLI for";
    };

    secretPath = mkOption {
      type = types.path;
      default = config.age.secrets."jamesbrink/heroku-key".path;
      description = "Path to the Heroku API key secret";
    };
  };

  config = mkIf cfg.enable {
    # Install Heroku CLI
    environment.systemPackages = with pkgs; [
      heroku
    ];

    # Configure Heroku authentication for the specified user
    system.activationScripts.herokuAuth = {
      text = ''
        if [ -f "${cfg.secretPath}" ]; then
          # Create .netrc file for Heroku authentication
          mkdir -p /home/${cfg.user}
          cat > /home/${cfg.user}/.netrc <<EOF
        machine api.heroku.com
          login ${cfg.user}@example.com
          password $(cat ${cfg.secretPath})
        machine git.heroku.com
          login ${cfg.user}@example.com
          password $(cat ${cfg.secretPath})
        EOF
          chmod 600 /home/${cfg.user}/.netrc
          chown ${cfg.user}:users /home/${cfg.user}/.netrc
        fi
      '';
      deps = [
        "users"
        "groups"
      ];
    };

    # Ensure the secret is available
    age.secrets."jamesbrink/heroku-key" = {
      file = "${config._module.args.secretsPath or ../secrets}/jamesbrink/heroku-key.age";
      owner = cfg.user;
      group = "users";
      mode = "0400";
    };
  };
}
