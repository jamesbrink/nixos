{ config, lib, pkgs, secretsPath, ... }:

{
  # Enable Nginx
  services.nginx = {
    enable = true;
    
    # Recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Virtual Host configuration
    virtualHosts."hal9000.home.urandom.io" = {
      forceSSL = true;
      useACMEHost = "hal9000.home.urandom.io";
      
      root = "/var/www/hal9000.home.urandom.io";
      
      # Basic configuration
      locations."/" = {
        index = "index.html index.htm";
      };

      # Security headers
      extraConfig = ''
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      '';
    };
  };

  # ACME/Let's Encrypt configuration
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@home.urandom.io";
    
    # Use production environment
    defaults.server = "https://acme-v02.api.letsencrypt.org/directory";
    
    certs."hal9000.home.urandom.io" = {
      dnsProvider = "route53";
      credentialsFile = config.age.secrets."secrets/global/aws/cert-credentials-secret.age".path;
      dnsPropagationCheck = true;
      dnsResolver = "1.1.1.1:53";
      extraLegoFlags = [
        "--dns.resolvers" "1.1.1.1:53"
        "--dns-timeout" "120"
        "--dns.propagation-wait" "120s"
      ];
      group = "nginx";
      reloadServices = [ "nginx" ];
    };
  };

  users.users.nginx.extraGroups = [ "acme" ];

  # Create web root directory
  systemd.tmpfiles.rules = [
    "d /var/www/hal9000.home.urandom.io 755 nginx nginx"
  ];

  # Open firewall ports
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
  };
}