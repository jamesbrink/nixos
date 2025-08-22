# PixInsight Cache Management

## Problem

PixInsight's tar.xz file gets garbage collected from the Nix store, causing build failures after flake updates or garbage collection.

## Solution

We maintain a permanent cache of the PixInsight installation file at `/var/cache/pixinsight/` on HAL9000.

## Setup

### Initial Setup (already done)

1. Copy the PixInsight tar.xz to the cache directory:

   ```bash
   sudo mkdir -p /var/cache/pixinsight
   sudo cp ~/Downloads/PI-linux-x64-1.9.3-20250402-c.tar.xz /var/cache/pixinsight/
   sudo chmod 644 /var/cache/pixinsight/*.tar.xz
   ```

2. The package now uses `package-cached.nix` which directly references this cache location.

### If the error returns

1. Check if the file exists in cache:

   ```bash
   ls -la /var/cache/pixinsight/
   ```

2. If missing, re-download from pixinsight.com or restore from backup:

   ```bash
   # Copy from Downloads if available
   sudo cp ~/Downloads/PI-linux-x64-1.9.3-20250402-c.tar.xz /var/cache/pixinsight/

   # Or add to nix store first if you have the file
   nix-prefetch-url --type sha256 file:///path/to/PI-linux-x64-1.9.3-20250402-c.tar.xz
   ```

### Version Updates

When updating PixInsight:

1. Download the new version
2. Copy to `/var/cache/pixinsight/`
3. Update version in `pkgs/pixinsight/package-cached.nix`
4. Update the sha256 hash

## Technical Details

- File: `PI-linux-x64-1.9.3-20250402-c.tar.xz`
- Location: `/var/cache/pixinsight/`
- SHA256: `06ss47jycq99wv8p2pg68b80zgrvcwph8qp35pappmq0mqgidq1h`
- Size: ~641 MB

## Files Modified

- `pkgs/pixinsight/package-cached.nix` - New package definition using cache
- `overlays/pixinsight.nix` - Updated to use cached package
- `hosts/hal9000/default.nix` - Added tmpfiles rule for cache directory
