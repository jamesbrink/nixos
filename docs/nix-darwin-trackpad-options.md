# nix-darwin Trackpad Configuration Options

This document lists all available trackpad configuration options in nix-darwin.

## system.defaults.trackpad Options

These options are under `system.defaults.trackpad.*`:

- **`ActuationStrength`**: 0 to enable Silent Clicking, 1 to disable. Default: 1
- **`Clicking`**: Whether to enable trackpad tap to click. Default: false
- **`Dragging`**: Whether to enable tap-to-drag. Default: false
- **`FirstClickThreshold`**: For normal click: 0 for light clicking, 1 for medium, 2 for firm. Default: 1
- **`SecondClickThreshold`**: For force touch: 0 for light clicking, 1 for medium, 2 for firm. Default: 1
- **`TrackpadRightClick`**: Whether to enable trackpad right click. Default: false
- **`TrackpadThreeFingerDrag`**: Whether to enable three finger drag. Default: false
- **`TrackpadThreeFingerTapGesture`**: 0 to disable three finger tap, 2 to trigger Look up & data detectors. Default: 2

## system.defaults.NSGlobalDomain Trackpad Options

These options are under `system.defaults.NSGlobalDomain.*`:

- **`"com.apple.trackpad.enableSecondaryClick"`**: Whether to enable trackpad secondary click. Default: true
- **`"com.apple.trackpad.forceClick"`**: Whether to enable trackpad force click. Default: null (unset)
- **`"com.apple.trackpad.scaling"`**: Configures the trackpad tracking speed (0 to 3). Default: "1"
- **`"com.apple.trackpad.trackpadCornerClickBehavior"`**: Configures the trackpad corner click behavior. Mode 1 enables right click. Default: null (unset)
- **`"com.apple.swipescrolldirection"`**: Whether to enable "Natural" scrolling direction. Default: true
- **`AppleEnableMouseSwipeNavigateWithScrolls`**: Enables swiping left or right with two fingers to navigate backward or forward. Default: true
- **`AppleEnableSwipeNavigateWithScrolls`**: Enables swiping left or right with two fingers to navigate backward or forward. Default: true

## Example Configuration

```nix
{
  system.defaults = {
    trackpad = {
      ActuationStrength = 0; # Enable silent clicking
      Clicking = true; # Enable tap to click
      Dragging = true; # Enable tap to drag
      FirstClickThreshold = 1; # Medium click pressure
      SecondClickThreshold = 1; # Medium force touch pressure
      TrackpadRightClick = true; # Enable right click
      TrackpadThreeFingerDrag = true; # Enable three finger drag
      TrackpadThreeFingerTapGesture = 2; # Three finger tap for data detectors
    };

    NSGlobalDomain = {
      "com.apple.trackpad.enableSecondaryClick" = true;
      "com.apple.trackpad.forceClick" = true;
      "com.apple.trackpad.scaling" = "1.5"; # Increase tracking speed
      "com.apple.trackpad.trackpadCornerClickBehavior" = 1; # Corner click for right click
      "com.apple.swipescrolldirection" = true; # Natural scrolling
      AppleEnableSwipeNavigateWithScrolls = true; # Two finger swipe navigation
    };
  };
}
```

## system.defaults.CustomUserPreferences for Advanced Trackpad Gestures

For trackpad gestures not directly exposed through nix-darwin options, use `system.defaults.CustomUserPreferences`:

```nix
{
  system.defaults.CustomUserPreferences = {
    "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
      # Mission Control - Swipe up with three fingers
      TrackpadThreeFingerVertSwipeGesture = 2;

      # Switch between full-screen apps - Swipe left/right with three fingers
      TrackpadThreeFingerHorizSwipeGesture = 2;

      # Notification Center - Two finger swipe from right edge
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;

      # Show Desktop - Spread with thumb and three fingers
      TrackpadFourFingerPinchGesture = 2;

      # Launchpad - Pinch with thumb and three fingers
      TrackpadFourFingerVertSwipeGesture = 2;

      # App Exposé - Three finger tap (0 to disable)
      TrackpadThreeFingerTapGesture = 0;
    };

    # Dock gesture preferences
    "com.apple.dock" = {
      "showLaunchpadGestureEnabled" = true;
      "showDesktopGestureEnabled" = true;
      "showMissionControlGestureEnabled" = true;
    };
  };
}
```

### Ensuring Settings Persist

If trackpad settings reset after reboot, add this activation script:

```nix
{
  system.activationScripts.postUserActivation.text = ''
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
```

## Important Notes

1. The options `TrackpadScroll` and `TrackpadScrollDirection` that appear in some configurations are **not valid** nix-darwin options. Use `"com.apple.swipescrolldirection"` instead for scroll direction.

2. All NSGlobalDomain options that contain dots must be quoted (e.g., `"com.apple.trackpad.scaling"`).

3. Some trackpad gestures (like Mission Control, App Exposé) are not directly configurable through standard nix-darwin options but can be set using `CustomUserPreferences` as shown above.

4. The tracking speed option uses a string value ("0" to "3") not a number.

5. To disable natural scrolling, set `"com.apple.swipescrolldirection" = false`.

6. `CustomUserPreferences` is a declarative wrapper around macOS `defaults write` commands and supports various value types including booleans, integers, strings, and nested attribute sets.
