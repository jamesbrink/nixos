# VSCode/Cursor theme extensions not available in Cursor marketplace
# These are packaged locally so they can be installed in both editors
{
  lib,
  vscode-utils,
  fetchFromGitHub,
  stdenv,
}:

{
  # Kanagawa theme - https://marketplace.visualstudio.com/items?itemName=qufiwefefwoyn.kanagawa
  kanagawa = vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "qufiwefefwoyn";
      name = "kanagawa";
      version = "1.5.1";
      sha256 = "0mwgbdis84npl8lhrxkrsi82y6igx9l975jnd37ziz8afyhs4q80";
    };
    meta = {
      description = "Kanagawa color scheme for VSCode";
      license = lib.licenses.mit;
    };
  };

  # Ocean Green theme (Osaka Jade) - https://marketplace.visualstudio.com/items?itemName=jovejonovski.ocean-green
  ocean-green = vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "jovejonovski";
      name = "ocean-green";
      version = "1.1.2";
      sha256 = "1kmwpag4hv9i4a19x688gn4z3y8ivh9g3817aavsvjcp7agn6hxi";
    };
    meta = {
      description = "Ocean Green dark theme for VSCode";
      license = lib.licenses.mit;
    };
  };

  # Flexoki theme - built from GitHub since not on marketplace
  flexoki = stdenv.mkDerivation rec {
    pname = "vscode-extension-kepano-flexoki";
    version = "2.0.0";

    src = fetchFromGitHub {
      owner = "kepano";
      repo = "flexoki";
      rev = version;
      sha256 = "00vbr3qp945fzwa65sskfhxj2bqgc56cx4zyd8i1m580vr8hv02g";
    };

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/vscode/extensions/kepano.flexoki
      cp -r vscode/* $out/share/vscode/extensions/kepano.flexoki/

      # Create package.json for VSCode to recognize it
      cat > $out/share/vscode/extensions/kepano.flexoki/package.json << EOF
      {
        "name": "flexoki",
        "displayName": "Flexoki",
        "description": "An inky color scheme for prose and code",
        "version": "${version}",
        "publisher": "kepano",
        "engines": { "vscode": "^1.60.0" },
        "categories": ["Themes"],
        "contributes": {
          "themes": [
            {
              "label": "Flexoki Dark",
              "uiTheme": "vs-dark",
              "path": "./Flexoki-Dark-color-theme.json"
            },
            {
              "label": "Flexoki Light",
              "uiTheme": "vs",
              "path": "./Flexoki-Light-color-theme.json"
            }
          ]
        }
      }
      EOF

      runHook postInstall
    '';

    meta = {
      description = "Flexoki - An inky color scheme for prose and code";
      homepage = "https://github.com/kepano/flexoki";
      license = lib.licenses.mit;
    };
  };
}
