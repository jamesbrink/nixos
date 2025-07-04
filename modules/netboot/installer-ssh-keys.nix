# Static SSH host keys for the netboot installer
# This ensures consistent SSH fingerprints when connecting to installer
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Disable automatic SSH key generation
  services.openssh.hostKeys = lib.mkForce [ ];

  # Create the SSH host keys via activation script
  # This runs earlier than systemd services and ensures keys are available
  system.activationScripts.installer-ssh-keys = lib.stringAfter [ "etc" ] ''
        echo "Setting up installer SSH host keys..."
        mkdir -p /etc/ssh
        
        # Only create keys if they don't exist
        if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
          echo "Creating ED25519 host key..."
          
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
          
          echo "SSH host key created successfully"
        else
          echo "SSH host key already exists"
        fi
        
        # Also create RSA key for compatibility
        if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
          echo "Creating RSA host key..."
          ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
        fi
        
        # Verify permissions
        chmod 600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
        chmod 644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true
        
        echo "SSH host keys setup complete"
  '';
}
