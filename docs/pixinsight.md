# PixInsight Installation Guide

This document covers the installation and configuration of PixInsight on NixOS systems.

## Overview

PixInsight is a commercial scientific image processing software designed for astrophotography. This repository includes a custom package for PixInsight 1.9.3 that properly integrates with NixOS.

## Prerequisites

1. **PixInsight License**: You need a valid PixInsight license (commercial or trial)
2. **Download Access**: Access to the PixInsight download portal
3. **System Requirements**: x86_64 Linux system with adequate GPU support

## Manual Installation Steps

### 1. Download PixInsight

1. Visit https://pixinsight.com/ and log in to your account
2. Navigate to the software distribution section
3. Download the Linux 64-bit version (filename: `PI-linux-x64-1.9.3-20250402-c.tar.xz`)

### 2. Add to Nix Store

After downloading, the file needs to be added to the target system's Nix store:

```bash
# Copy the file to the target system (if downloaded elsewhere)
scp ~/Downloads/PI-linux-x64-1.9.3-20250402-c.tar.xz user@hostname:/path/to/downloads/

# On the target system, add to Nix store
nix-store --add-fixed sha256 /path/to/PI-linux-x64-1.9.3-20250402-c.tar.xz
```

Expected hash: `sha256-MOAWH64A13vVLeNiBC9nO78P0ELmXXHR5ilh5uUhWhs=`

**Note:** The PixInsight tarball has been permanently stored at `/opt/pixinsight/PI-linux-x64-1.9.3-20250402-c.tar.xz` on hal9000 and added to the Nix store at `/nix/store/3z10lwax02gv278sspwmigppsxjqba01-PI-linux-x64-1.9.3-20250402-c.tar.xz`.

**Alternative Storage:** For systems where you want to avoid re-downloading, you can store the tarball in a permanent location like `/opt/pixinsight/` and reference it when running `nix-store --add-fixed`. This prevents the file from being garbage collected and makes rebuilds faster.

### 3. Enable in Configuration

Add PixInsight to your host's system packages:

```nix
environment.systemPackages = with pkgs; [
  # ... other packages
  pixinsight
];
```

Also ensure you have allowed the insecure qtwebkit dependency:

```nix
nixpkgs.config = {
  allowUnfree = true;
  permittedInsecurePackages = [
    "qtwebkit-5.212.0-alpha4"
  ];
};
```

### 4. Deploy

Deploy the configuration to your system:

```bash
deploy hostname
```

## Package Details

### Location

The custom PixInsight package is located at:

- Package definition: `pkgs/pixinsight/package.nix`
- Overlay: `overlays/pixinsight.nix`

### Features

- **Version**: 1.9.3-20250402 (latest as of July 2025)
- **Qt6 Support**: Uses Qt6 packages instead of Qt5
- **Desktop Integration**: Properly configured desktop entry for GNOME/KDE
- **Wayland Compatibility**: Automatically runs in X11 mode (XWayland) for compatibility

### Technical Details

The package:

- Uses `requireFile` to handle the commercial download requirement
- Patches the installer to work with Nix's filesystem layout
- Removes plugin signatures that cause issues outside of `/opt`
- Wraps the binary with necessary environment variables
- Forces X11 mode with `QT_QPA_PLATFORM=xcb` for Wayland compatibility

## Troubleshooting

### Application doesn't appear in menu

If PixInsight doesn't appear in your application menu after installation:

1. Try restarting GNOME Shell (Alt+F2, type 'r', press Enter)
2. Or log out and back in

### Wayland compatibility issues

The package automatically forces X11 mode through XWayland. If you still experience issues:

1. Verify X11 mode is active by checking the process environment
2. Ensure XWayland is installed and running on your system

### Missing dependencies

If PixInsight fails to start due to missing libraries:

1. Check the logs for specific library errors
2. The package sets `autoPatchelfIgnoreMissingDeps = true` for exotic Qt libraries
3. Most common dependencies are already included in the package

## Updates

When a new version of PixInsight is released:

1. Update the version in `pkgs/pixinsight/package.nix`
2. Download the new version
3. Update the SHA256 hash after adding to nix store
4. Test and deploy

## License

PixInsight is commercial software. Ensure you have a valid license before using.
