# Keep the agenix ramdisk mounted across console logout.
#
# On Darwin, agenix decrypts secrets onto an `hdiutil attach ram://` HFS
# volume mounted at /run/agenix.d. DiskArbitration treats ram disks as
# removable media and unmounts them when the console user logs out
# ("console user is not logged in. unmounting disk"), leaving /run/agenix
# dangling until the next activation. Every secret consumer then reads empty
# values (e.g. CLAUDE_CODE_OAUTH_TOKEN_* in ~/.config/environment.d).
#
# AutomountDisksWithoutUserLogin makes diskarbitrationd leave removable disks
# mounted without a logged-in console user.
_:

{
  system.activationScripts.postActivation.text = ''
    defaults write /Library/Preferences/SystemConfiguration/autodiskmount \
      AutomountDisksWithoutUserLogin -bool true
  '';
}
