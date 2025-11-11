# Darwin-specific user configuration for kids with parental controls
# This creates a managed user account with Screen Time restrictions
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Create standard (non-admin) user account for kids
  users.users.girls = {
    name = "girls";
    home = "/Users/girls";
    shell = pkgs.zsh;
    description = "Kids Account";
    uid = 502; # macOS user UID (typically starts at 501)
    # Standard user - not in admin/wheel groups for restricted access
  };

  # Register as a known user so nix-darwin manages it
  users.knownUsers = [ "girls" ];

  # Create the user and home directory before home-manager activation
  system.activationScripts.preActivation.text = lib.mkBefore ''
    echo "Ensuring girls user exists..."

    # Check if user exists
    if ! dscl . -read /Users/girls &>/dev/null; then
      echo "Creating girls user account..."

      # Create the user
      sudo dscl . -create /Users/girls
      sudo dscl . -create /Users/girls UserShell ${pkgs.zsh}/bin/zsh
      sudo dscl . -create /Users/girls RealName "Kids Account"
      sudo dscl . -create /Users/girls UniqueID 502
      sudo dscl . -create /Users/girls PrimaryGroupID 20
      sudo dscl . -create /Users/girls NFSHomeDirectory /Users/girls

      # Create home directory
      sudo mkdir -p /Users/girls
      sudo chown -R 502:20 /Users/girls
      sudo chmod 755 /Users/girls

      echo "Girls user created successfully"
    else
      echo "Girls user already exists"

      # Ensure home directory exists
      if [ ! -d /Users/girls ]; then
        echo "Creating home directory for girls user..."
        sudo mkdir -p /Users/girls
        sudo chown -R 502:20 /Users/girls
        sudo chmod 755 /Users/girls
      fi
    fi
  '';

  # Home-manager configuration for the girls user
  home-manager.users.girls =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        # Educational and kid-friendly apps
        # Add appropriate packages here based on needs
      ];

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        shellAliases = {
          ll = "ls -l";
        };

        history.size = 10000;
      };

      # Basic git configuration (if needed)
      programs.git = {
        enable = true;
        userName = "Girls";
        userEmail = "girls@local";
      };

      home.stateVersion = "25.05";
    };

  # Parental Controls Configuration
  # These are applied via system activation scripts that set up Screen Time restrictions
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "Setting up parental controls for girls user..."

    # Create managed preferences directory for the girls user
    sudo mkdir -p "/Library/Managed Preferences/girls"

    # Application Access Restrictions
    # This restricts certain applications and features
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowedGlobalBackgroundBluetoothModification -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowAccountModification -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowPasswordChange -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowCloudPrivateRelay -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowDiagnosticSubmission -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowCloudDocumentSync -bool true

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowCloudKeychainSync -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowCloudPhotoLibrary -bool true

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowCamera -bool true

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowMultiplayerGaming -bool true

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowAddingGameCenterFriends -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowUIAppInstallation -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowAppRemoval -bool false

    # Safari Content Filtering
    # Enable safe browsing and restrict adult content
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.Safari" \
      AutoFillPasswords -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.Safari" \
      AutoFillCreditCardData -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.Safari" \
      SafeBrowsingEnabled -bool true

    # Web Content Filter - Auto filter mode (filters adult content)
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.familycontrols.contentfilter" \
      useContentFilter -bool true

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.familycontrols.contentfilter" \
      filterType -string "auto"

    # Time Limits Configuration
    # Set reasonable screen time limits (in seconds per day)
    # 4 hours on weekdays, unlimited on weekends
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2" \
      enabled -bool true

    # Weekday time limit: 4 hours (14400 seconds)
    sudo /usr/libexec/PlistBuddy -c "Add :time-limits:weekday-allowance:secondsPerDay integer 14400" \
      "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2.plist" 2>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Set :time-limits:weekday-allowance:secondsPerDay 14400" \
      "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2.plist"

    # Weekend time limit: Unlimited (no limit set)

    # Bedtime restrictions: No device use from 9 PM to 7 AM
    sudo /usr/libexec/PlistBuddy -c "Add :time-limits:bedtime:start-time string '21:00'" \
      "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2.plist" 2>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Set :time-limits:bedtime:start-time '21:00'" \
      "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2.plist"

    sudo /usr/libexec/PlistBuddy -c "Add :time-limits:bedtime:end-time string '07:00'" \
      "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2.plist" 2>/dev/null || \
    sudo /usr/libexec/PlistBuddy -c "Set :time-limits:bedtime:end-time '07:00'" \
      "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2.plist"

    # Store Restrictions - Prevent iTunes Store purchases and app downloads
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowITunes -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowAppStore -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      forceITunesStorePasswordEntry -bool true

    # Privacy Settings
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowSpotlightInternetResults -bool false

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      allowDefinitionLookup -bool true

    # Game Center Restrictions
    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      ratingRegion -string "us"

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      ratingApps -int 500

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      ratingMovies -int 500

    sudo /usr/bin/defaults write "/Library/Managed Preferences/girls/com.apple.applicationaccess" \
      ratingTVShows -int 500

    # Fix ownership and permissions
    sudo chown -R root:wheel "/Library/Managed Preferences/girls"
    sudo chmod -R 755 "/Library/Managed Preferences/girls"
    sudo chmod 644 "/Library/Managed Preferences/girls/"*.plist 2>/dev/null || true

    echo "Parental controls configured for girls user"
    echo ""
    echo "IMPORTANT: Parental controls summary for 'girls' user:"
    echo "  - Daily time limits: 4 hours (weekdays), Unlimited (weekends)"
    echo "  - Bedtime: 9 PM - 7 AM (device locked)"
    echo "  - App Store: Disabled (cannot download/purchase apps)"
    echo "  - Account modifications: Disabled (cannot change settings)"
    echo "  - Web filtering: Enabled (adult content filtered)"
    echo "  - Safe browsing: Enabled"
    echo "  - Game Center friends: Cannot add new friends"
    echo "  - Content ratings: Age 9+ for apps, movies, TV shows"
    echo ""
    echo "To adjust these settings, edit: users/regular/girls-darwin.nix"
    echo "Then rebuild with: darwin-rebuild switch --flake ."
  '';
}
