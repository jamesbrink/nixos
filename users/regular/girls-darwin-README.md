# Girls User Profile - Parental Controls for macOS

This module creates a managed user account for kids with comprehensive parental controls using macOS Screen Time features.

## Overview

The `girls-darwin.nix` module creates a standard (non-admin) user account with the following parental control features:

### Time Limits

- **Weekdays**: 4 hours of screen time per day
- **Weekends**: 6 hours of screen time per day
- **Bedtime**: Device locked from 9 PM to 7 AM

### Application Restrictions

- **App Store**: Disabled (cannot download or purchase apps)
- **App Installation**: Disabled (requires admin password)
- **App Removal**: Disabled
- **Game Center**: Can play multiplayer games but cannot add new friends

### Account & Privacy

- **Account Modifications**: Disabled (cannot change user settings)
- **Password Changes**: Disabled
- **iCloud Keychain**: Disabled
- **iCloud Documents**: Enabled (for homework/projects)
- **iCloud Photos**: Enabled
- **Spotlight Internet Results**: Disabled

### Web Safety

- **Content Filter**: Enabled (automatically filters adult content)
- **Safe Browsing**: Enabled (protects against malicious websites)
- **AutoFill**: Disabled for passwords and credit cards

### Content Ratings

- Apps, Movies, and TV Shows restricted to age 9+ (rating 500)
- US rating system applied

## Usage

### Enabling on a Host

To enable this user profile on a Darwin host (like sevastopol), add the following to your host configuration:

```nix
{
  imports = [
    # ... other imports ...
    ../../users/regular/girls-darwin.nix
  ];
}
```

For sevastopol, edit `hosts/sevastopol/default.nix` and add the import.

### First Time Setup

1. Add the import to your host configuration
2. Rebuild and switch: `darwin-rebuild switch --flake .`
3. The user account will be created with home directory at `/Users/girls`
4. Set the user password: `sudo passwd girls`
5. Log out and log in as the `girls` user to verify parental controls

### Setting a Password

After the first deployment, you must set a password for the girls user:

```bash
sudo passwd girls
```

Choose a secure password that the kids don't know, or set a simple password if you're using Screen Time passcode protection.

## Customization

### Adjusting Time Limits

Edit the time limits in `users/regular/girls-darwin.nix`:

```nix
# Weekday time limit (in seconds): 4 hours = 14400 seconds
sudo /usr/libexec/PlistBuddy -c "Set :time-limits:weekday-allowance:secondsPerDay 14400" ...

# Weekend time limit (in seconds): 6 hours = 21600 seconds
sudo /usr/libexec/PlistBuddy -c "Set :time-limits:weekend-allowance:secondsPerDay 21600" ...
```

Common time conversions:

- 2 hours = 7200 seconds
- 3 hours = 10800 seconds
- 4 hours = 14400 seconds
- 5 hours = 18000 seconds
- 6 hours = 21600 seconds

### Changing Bedtime Hours

Edit the bedtime restrictions:

```nix
# Start time (24-hour format)
sudo /usr/libexec/PlistBuddy -c "Set :time-limits:bedtime:start-time '21:00'" ...

# End time (24-hour format)
sudo /usr/libexec/PlistBuddy -c "Set :time-limits:bedtime:end-time '07:00'" ...
```

### Adding Educational Apps

You can add educational apps to the user's package list:

```nix
home-manager.users.girls = { pkgs, ... }: {
  home.packages = with pkgs; [
    # Educational and kid-friendly apps
    # Examples (add what's available in nixpkgs):
    # scratch  # Programming for kids
    # gcompris # Educational activities
  ];
};
```

### Adjusting Content Ratings

Change the content rating values (based on US ratings):

- `100` = Age 4+
- `200` = Age 9+
- `300` = Age 12+
- `500` = Age 13+
- `600` = Age 17+
- `1000` = No restrictions

```nix
sudo /usr/bin/defaults write ".../com.apple.applicationaccess" \
  ratingApps -int 200  # Change to desired rating
```

## Technical Details

### Implementation

The parental controls are implemented using:

1. **User Account Management**: nix-darwin's `users.users` and `users.knownUsers` options
2. **Managed Preferences**: System activation scripts write plist files to `/Library/Managed Preferences/girls/`
3. **Key Plist Files**:
   - `com.apple.applicationaccess.plist` - App and feature restrictions
   - `com.apple.familycontrols.contentfilter.plist` - Web content filtering
   - `com.apple.familycontrols.timelimits.v2.plist` - Screen time limits
   - `com.apple.Safari.plist` - Safari-specific restrictions

### Verification

After deployment, verify the settings:

```bash
# Check managed preferences
sudo defaults read "/Library/Managed Preferences/girls/com.apple.applicationaccess"

# Check time limits
sudo defaults read "/Library/Managed Preferences/girls/com.apple.familycontrols.timelimits.v2"

# Check content filter
sudo defaults read "/Library/Managed Preferences/girls/com.apple.familycontrols.contentfilter"
```

### Removing Parental Controls

To remove parental controls:

1. Remove the import from your host configuration
2. Remove the user from `users.knownUsers`
3. Rebuild: `darwin-rebuild switch --flake .`
4. Manually delete managed preferences: `sudo rm -rf "/Library/Managed Preferences/girls"`
5. Delete the user (if desired): `sudo dscl . -delete /Users/girls`

## Limitations

### What This Module Does NOT Cover

1. **App-Specific Time Limits**: This module sets global time limits, not per-app limits
2. **Screen Time Passcode**: You should set this manually in System Settings to prevent kids from disabling restrictions
3. **Communication Limits**: Contact restrictions need to be set up through Screen Time UI
4. **Location Services**: Location sharing and Find My need to be configured separately
5. **Purchase Requests**: If using Family Sharing, approval workflows need additional setup

### Setting Screen Time Passcode

After creating the user, you should set a Screen Time passcode to prevent tampering:

1. Log in as the girls user
2. Open System Settings > Screen Time
3. Click "Turn On Screen Time"
4. Click "Use Screen Time Passcode"
5. Enter a passcode (different from the user password)
6. Log out and back in as your admin user

## Troubleshooting

### Parental Controls Not Applied

If restrictions aren't working:

1. Check that the plist files exist: `ls -la "/Library/Managed Preferences/girls/"`
2. Verify permissions: `sudo ls -l "/Library/Managed Preferences/girls/"`
3. Log out and log back in as the girls user
4. Rebuild the configuration: `darwin-rebuild switch --flake .`

### User Cannot Log In

If the user cannot log in after creation:

1. Ensure you set a password: `sudo passwd girls`
2. Check user exists: `dscl . -list /Users | grep girls`
3. Verify home directory: `ls -la /Users/girls`

### Time Limits Not Working

macOS Screen Time may need additional setup through the GUI:

1. Log in as admin user
2. Open System Settings > Screen Time
3. Select the girls user from the sidebar
4. Verify and enable "Screen Time" if not already on

## Security Considerations

### Admin Password Protection

Ensure your admin password is strong and not known to the kids, as they could:

- Boot into recovery mode and reset the girls password
- Create a new admin user
- Disable parental controls

### Physical Access

With physical access to the machine, tech-savvy kids might:

- Boot from external drive to bypass restrictions
- Reset NVRAM to clear some settings
- Use recovery mode to access files

Consider enabling FileVault encryption and setting a firmware password for additional security.

### Network-Level Filtering

This module only controls the device. For comprehensive protection:

- Use network-level DNS filtering (OpenDNS Family Shield, NextDNS, etc.)
- Set router-level parental controls
- Consider using parental control software with reporting features

## References

- [Apple Support: Screen Time](https://support.apple.com/guide/mac-help/set-up-screen-time-for-a-child-mchlc5595037/mac)
- [nix-darwin User Management](https://github.com/LnL7/nix-darwin/blob/master/modules/users/default.nix)
- [macOS Configuration Profiles](https://support.apple.com/guide/deployment/intro-to-mdm-dep7b1c0af9/web)

## Support

For questions or issues:

- Check nix-darwin documentation: `man configuration.nix`
- Review logs: `tail -f /tmp/nix-darwin-activation.log`
- Test in a VM before deploying to production hardware
