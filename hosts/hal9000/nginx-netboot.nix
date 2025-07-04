{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Netboot root directory on ZFS pool
  netbootRoot = "/export/storage-fast/netboot";
in
{
  # Add netboot virtual host to nginx
  services.nginx.virtualHosts = {
    # Netboot server on port 8079 (matching old configuration)
    "netboot.home.urandom.io" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8079;
        }
      ];

      root = netbootRoot;

      extraConfig = ''
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
      '';

      locations = {
        "/" = {
          extraConfig = ''
            # Allow access from N100 network and Tailscale
            allow 10.70.100.0/24;
            allow 100.64.0.0/10;
            deny all;
          '';
        };

        # Serve TFTP boot files via HTTP (for iPXE chainloading)
        "/boot/" = {
          alias = "/export/storage-fast/netboot/tftp/";
          extraConfig = ''
            autoindex on;
            # Allow access from N100 network and Tailscale
            allow 10.70.100.0/24;
            allow 100.64.0.0/10;
            deny all;
          '';
        };

        # Custom netboot.xyz menu for N100 auto-detection
        "/custom/" = {
          alias = "/export/storage-fast/netboot/custom/";
          extraConfig = ''
            autoindex on;
            # Allow access from N100 network and Tailscale
            allow 10.70.100.0/24;
            allow 100.64.0.0/10;
            deny all;
          '';
        };

        # MAC-based configuration endpoint
        # Handles requests like /config?mac=aa:bb:cc:dd:ee:ff
        "~ ^/config$" = {
          extraConfig = ''
            # Allow access from N100 network and Tailscale
            allow 10.70.100.0/24;
            allow 100.64.0.0/10;
            deny all;

            # Check if mac parameter exists
            if ($arg_mac = "") {
              return 400 "MAC address parameter required";
            }

            # Rewrite to serve MAC-specific config file
            rewrite ^.*$ /configs/$arg_mac.yaml break;

            # Set proper content type
            add_header Content-Type "text/yaml";

            # Try to serve the file, return 404 if not found
            try_files $uri =404;
          '';
        };

        # Legacy boot.ipxe location (for compatibility)
        "/ipxe/boot.ipxe" = {
          extraConfig = ''
            # This is now handled by TFTP with hostname-based files
            # Provide a fallback generic boot menu
            return 200 "#!ipxe\necho Legacy boot.ipxe - Please use TFTP for hostname-based booting\necho Your hostname should be set by DHCP\nprompt Press any key to exit\nexit";
            add_header Content-Type "text/plain";
          '';
        };

      };
    };
  };

  # Open firewall port for netboot HTTP server
  networking.firewall.allowedTCPPorts = [ 8079 ];

  # Create netboot directory structure
  systemd.tmpfiles.rules = [
    "d ${netbootRoot}/configs 0755 nginx nginx -"
    "d ${netbootRoot}/images 0755 nginx nginx -"
    "d ${netbootRoot}/scripts 0755 nginx nginx -"
  ];
}
