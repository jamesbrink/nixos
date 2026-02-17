# Increase system file descriptor limits on macOS
# Prevents "Too many open files" errors during Nix builds
{ ... }:

{
  # Set system-wide file descriptor limits via launchd
  # This runs at boot before any daemons start
  launchd.daemons.limit-maxfiles = {
    command = "/bin/launchctl limit maxfiles 65536 524288";
    serviceConfig = {
      Label = "io.urandom.limit-maxfiles";
      RunAtLoad = true;
      LaunchOnlyOnce = true;
    };
  };
}
