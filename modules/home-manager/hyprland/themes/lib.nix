{ }:

let
  # Repository root (used to locate shared assets such as the Omarchy submodule)
  repoRoot = ../../../../.;
  repoRootStr = builtins.toString repoRoot;

  # Upstream Omarchy themes (git submodule)
  omarchyThemesDir = repoRootStr + "/external/omarchy/themes";

  # Optional local overrides. Leave the directory empty (or absent) if unused.
  localWallpapersDir = repoRootStr + "/modules/home-manager/hyprland/wallpapers";

  # Helper to locate a wallpaper image for a given theme/filename pair.
  # Preference order: local overrides → Omarchy submodule.
  getWallpaperSource =
    themeName: wallpaperName:
    let
      localPath = localWallpapersDir + "/${themeName}/${wallpaperName}";
      upstreamPath = omarchyThemesDir + "/${themeName}/backgrounds/${wallpaperName}";
    in
    if builtins.pathExists localPath then localPath else upstreamPath;

  themeFiles = [
    ./catppuccin-latte.nix
    ./catppuccin.nix
    ./everforest.nix
    ./flexoki-light.nix
    ./gruvbox.nix
    ./kanagawa.nix
    ./matte-black.nix
    ./nord.nix
    ./osaka-jade.nix
    ./ristretto.nix
    ./rose-pine.nix
    ./tokyo-night.nix
  ];
in
{
  inherit themeFiles omarchyThemesDir getWallpaperSource;
}
