{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.file-sharing;
in
{
  options.services.file-sharing = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable macOS file sharing (SMB/AFP)";
    };

    shareName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "The name that will appear when browsing for this computer on the network";
    };

    sharedFolders = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "/Users/Shared"
        "/Volumes/Data"
      ];
      description = "List of folders to share via SMB";
    };
  };

  config = mkIf cfg.enable {
    # Enable file sharing
    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "Configuring file sharing..."

      # Enable SMB sharing
      sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null || true

      # Set the NetBIOS name
      sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "${cfg.shareName}"

      # Enable SMB for the current user
      sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server.plist EnabledUsers -array "jamesbrink"

      # Set workgroup (optional, defaults to WORKGROUP)
      sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server WorkgroupName -string "WORKGROUP"

      # Enable guest access (optional, disabled by default for security)
      # sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool YES

      # Configure shared folders
      ${concatMapStrings (folder: ''
        # Share ${folder} if it exists
        if [ -d "${folder}" ]; then
          echo "Sharing folder: ${folder}"
          sudo sharing -a "${folder}" -S "${builtins.baseNameOf folder}" -n "${builtins.baseNameOf folder}" 2>/dev/null || true
        fi
      '') cfg.sharedFolders}

      # Restart SMB service to apply changes
      sudo launchctl unload /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null || true
      sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null || true

      echo "File sharing configuration complete"
    '';
  };
}
