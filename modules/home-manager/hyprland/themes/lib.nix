{
  omarchySrc ? null,
}:

let
  # Repository root (used to locate shared assets such as the Omarchy submodule)
  repoRoot = ../../../../.;

  # Upstream Omarchy themes (git submodule)
  omarchyBase = if omarchySrc != null then omarchySrc else repoRoot + "/external/omarchy";
  omarchyThemesDir = omarchyBase + "/themes";

  # Optional local overrides. Leave the directory empty (or absent) if unused.
  localWallpapersDir = repoRoot + "/modules/home-manager/hyprland/wallpapers";

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

  ghosttyConfigText =
    ghosttyDef:
    let
      scalarFields = [
        "background"
        "foreground"
        "cursor-color"
        "cursor-text"
        "selection-background"
        "selection-foreground"
      ];
      renderField = field: if ghosttyDef ? ${field} then "${field} = ${ghosttyDef.${field}}\n" else "";
      paletteLines =
        if ghosttyDef ? palette then
          builtins.concatStringsSep "" (map (entry: "palette = ${entry}\n") ghosttyDef.palette)
        else
          "";
      themeLine = if ghosttyDef ? theme then "theme = ${ghosttyDef.theme}\n" else "";
    in
    themeLine + builtins.concatStringsSep "" (map renderField scalarFields) + paletteLines;

  ghosttyThemeName =
    themeDef:
    let
      ghosttyDef = themeDef.ghostty or { };
      attrCount = builtins.length (builtins.attrNames ghosttyDef);
    in
    if ghosttyDef ? theme && attrCount == 1 then ghosttyDef.theme else themeDef.name;

  ghosttyThemeMap = builtins.listToAttrs (
    map (
      themeFile:
      let
        themeDef = import themeFile;
      in
      {
        name = themeDef.name;
        value = ghosttyThemeName themeDef;
      }
    ) themeFiles
  );

  ghosttyCustomThemes = builtins.listToAttrs (
    builtins.concatLists (
      map (
        themeFile:
        let
          themeDef = import themeFile;
          ghosttyDef = themeDef.ghostty or { };
          attrCount = builtins.length (builtins.attrNames ghosttyDef);
          needsFile = attrCount > 0 && (!(ghosttyDef ? theme && attrCount == 1));
        in
        if needsFile then
          [
            {
              name = ".config/ghostty/themes/${themeDef.name}";
              value = {
                text = ghosttyConfigText ghosttyDef;
              };
            }
          ]
        else
          [ ]
      ) themeFiles
    )
  );
  lowercase =
    str:
    builtins.replaceStrings
      [
        "A"
        "B"
        "C"
        "D"
        "E"
        "F"
        "G"
        "H"
        "I"
        "J"
        "K"
        "L"
        "M"
        "N"
        "O"
        "P"
        "Q"
        "R"
        "S"
        "T"
        "U"
        "V"
        "W"
        "X"
        "Y"
        "Z"
      ]
      [
        "a"
        "b"
        "c"
        "d"
        "e"
        "f"
        "g"
        "h"
        "i"
        "j"
        "k"
        "l"
        "m"
        "n"
        "o"
        "p"
        "q"
        "r"
        "s"
        "t"
        "u"
        "v"
        "w"
        "x"
        "y"
        "z"
      ]
      str;

  slugify = name: builtins.replaceStrings [ " " "_" "/" ] [ "-" "-" "-" ] (lowercase name);

  themeDefs = map (themeFile: import themeFile) themeFiles;

  resolveWallpaperPaths =
    theme: map (wallpaper: getWallpaperSource theme.name wallpaper) (theme.wallpapers or [ ]);

  buildMetadata =
    theme:
    let
      slug = lowercase (if theme ? slug && theme.slug != "" then theme.slug else slugify theme.name);
      wallpaperPaths = resolveWallpaperPaths theme;
    in
    {
      inherit slug;
      wallpapers = wallpaperPaths;
      name = theme.name;
      displayName = theme.displayName or theme.name;
      kind = theme.kind or null;
      nvim = theme.nvim or { };
      vscode = theme.vscode or { };
      cursor = theme.cursor or { };
      alacritty = theme.alacritty or { };
      ghostty = theme.ghostty or { };
      kitty = theme.kitty or { };
      hyprland = theme.hyprland or { };
      waybar = theme.waybar or { };
      tmux = theme.tmux or { };
      walker = theme.walker or { };
      btop = theme.btop or { };
    };

  themeMetadata = map buildMetadata themeDefs;

  wallpaperStoreRefs = builtins.concatLists (map resolveWallpaperPaths themeDefs);

  themeMetadataJSON = builtins.toJSON {
    version = 1;
    themes = themeMetadata;
  };
in
{
  inherit
    themeFiles
    omarchyThemesDir
    getWallpaperSource
    themeDefs
    themeMetadata
    themeMetadataJSON
    wallpaperStoreRefs
    ghosttyConfigText
    ghosttyThemeName
    ghosttyThemeMap
    ghosttyCustomThemes
    ;
}
