{
  omarchySrc ? null,
}:

let
  # Repository root (used to locate shared assets such as the Omarchy submodule)
  repoRoot = ../../.;

  # Upstream Omarchy themes (git submodule) - now primarily used as source for sync
  omarchyBase = if omarchySrc != null then omarchySrc else repoRoot + "/external/omarchy";
  omarchyThemesDir = omarchyBase + "/themes";

  # Wallpapers synced from omarchy, with support for local overrides
  wallpapersDir = repoRoot + "/modules/themes/wallpapers";

  # Helper to locate a wallpaper image for a given theme/filename pair.
  # Wallpapers are synced from omarchy to modules/themes/wallpapers/
  getWallpaperSource = themeName: wallpaperName: wallpapersDir + "/${themeName}/${wallpaperName}";

  themeFiles = [
    ./definitions/catppuccin-latte.nix
    ./definitions/catppuccin.nix
    ./definitions/everforest.nix
    ./definitions/flexoki-light.nix
    ./definitions/gruvbox.nix
    ./definitions/kanagawa.nix
    ./definitions/matte-black.nix
    ./definitions/nord.nix
    ./definitions/osaka-jade.nix
    ./definitions/ristretto.nix
    ./definitions/rose-pine.nix
    ./definitions/tokyo-night.nix
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

  # Parse colors.toml file for a theme
  # Returns colors as attrset, or empty set if file doesn't exist
  parseColorsToml =
    themeName:
    let
      colorsFile = ./colors + "/${slugify themeName}.toml";
    in
    if builtins.pathExists colorsFile then
      let
        content = builtins.readFile colorsFile;
        # Simple TOML parser for flat key=value pairs
        splitLines = builtins.split "\n" content;
        # Filter out empty strings and matched separators (which are lists)
        nonEmptyLines = builtins.filter (l: builtins.isString l && l != "") splitLines;
        # Filter out comments
        lines = builtins.filter (l: builtins.match "^#.*" l == null) nonEmptyLines;
        parseLine =
          line:
          let
            parts = builtins.match "^([^=]+)=(.+)$" line;
          in
          if parts != null then
            let
              key = builtins.head (builtins.filter (x: x != "") (builtins.split " " (builtins.elemAt parts 0)));
              value = builtins.replaceStrings [ "\"" " " ] [ "" "" ] (builtins.elemAt parts 1);
            in
            {
              name = key;
              value = value;
            }
          else
            null;
        parsed = builtins.filter (x: x != null) (map parseLine lines);
      in
      builtins.listToAttrs parsed
    else
      { };

  themeDefs = map (themeFile: import themeFile) themeFiles;

  resolveWallpaperPaths =
    theme: map (wallpaper: getWallpaperSource theme.name wallpaper) (theme.wallpapers or [ ]);

  buildMetadata =
    theme:
    let
      slug = lowercase (if theme ? slug && theme.slug != "" then theme.slug else slugify theme.name);
      wallpaperPaths = resolveWallpaperPaths theme;
      colors = if theme ? colors then theme.colors else parseColorsToml theme.name;
    in
    {
      inherit slug;
      inherit colors;
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
