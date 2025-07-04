# Static SSH host keys for the netboot installer
# This ensures consistent SSH fingerprints when connecting to installer
{ config, lib, pkgs, ... }:

{
  # Set static SSH host keys for the installer
  services.openssh.hostKeys = lib.mkForce [
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
      # Pre-generated key to ensure consistent fingerprint
      # Public key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOPbIRL/3GfgzXlTNDu0bdHO7XWIUFmIWko9jdgIRM+1 root@nixos-installer
      # Fingerprint: SHA256:g8TZ9eNWHkB051QgizaF/1Y38hmqpLsr+e+R7wtqd0E
    }
  ];

  # Create the SSH host key at boot
  systemd.services.installer-ssh-keys = {
    description = "Generate installer SSH host keys";
    wantedBy = [ "sshd.service" ];
    before = [ "sshd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /etc/ssh
      
      # Write the pre-generated ED25519 key
      cat > /etc/ssh/ssh_host_ed25519_key << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACDj2yES/9xn4M15UzQ7tG3Rzu11iFBZiFpKPY3YCETPtQAAAKCKPgJ9ij4C
fQAAAAtzc2gtZWQyNTUxOQAAACDj2yES/9xn4M15UzQ7tG3Rzu11iFBZiFpKPY3YCETPtQ
AAAEBacFJzJ8TN+jKJxwqgGLnKFMLzU3kXZKFGLg7vGRBHvePbIRL/3GfgzXlTNDu0bdHO
7XWIUFmIWko9jdgIRM+1AAAAFnJvb3RAbml4b3MtaW5zdGFsbGVyAQIDBAUG
-----END OPENSSH PRIVATE KEY-----
EOF
      
      chmod 600 /etc/ssh/ssh_host_ed25519_key
      
      # Generate the public key
      ${pkgs.openssh}/bin/ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub
    '';
  };
}