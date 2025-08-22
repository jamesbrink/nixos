{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  unixtools,
  fakeroot,
  mailcap,
  libGL,
  libpulseaudio,
  alsa-lib,
  nss,
  gd,
  gst_all_1,
  nspr,
  expat,
  fontconfig,
  dbus,
  glib,
  zlib,
  openssl,
  libdrm,
  cups,
  avahi-compat,
  xorg,
  wayland,
  libudev0-shim,
  bubblewrap,
  libjpeg8,
  gdk-pixbuf,
  gtk3,
  pango,
  qt6Packages,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "pixinsight";
  version = "1.9.3-20250402";

  # Use the cached file directly - this prevents garbage collection issues
  src =
    let
      cachedPath = "/var/cache/pixinsight/PI-linux-x64-${finalAttrs.version}-c.tar.xz";
    in
    if builtins.pathExists cachedPath then
      cachedPath
    else
      # Fallback to requireFile if cache doesn't exist
      builtins.fetchurl {
        url = "file://${cachedPath}";
        sha256 = "06ss47jycq99wv8p2pg68b80zgrvcwph8qp35pappmq0mqgidq1h";
      };

  sourceRoot = ".";

  nativeBuildInputs = [
    unixtools.script
    fakeroot
    qt6Packages.wrapQtAppsHook
    autoPatchelfHook
    mailcap
    libudev0-shim
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libGL
    libpulseaudio
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
    alsa-lib
    fontconfig
    zlib
    nss
    gd
    nspr
    expat
    dbus
    glib
    openssl
    libdrm
    cups
    avahi-compat

    libjpeg8
    gdk-pixbuf
    gtk3
    pango

    qt6Packages.qtbase
    qt6Packages.qtmultimedia
    qt6Packages.qtcharts
    qt6Packages.qtdeclarative
    qt6Packages.qtquick3d
    qt6Packages.qtquicktimeline
    qt6Packages.qttools
    qt6Packages.qtwebengine
  ];

  runtimeDependencies = [
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXtst
    xorg.libxkbfile
    wayland
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    script ${finalAttrs.src} --noexec --target pixinsight

    pixinsight_dir="pixinsight/opt/PixInsight"

    # Ensure PixInsight is executable
    chmod +x "$pixinsight_dir/bin/PixInsight"
    chmod -R u+w "$pixinsight_dir"

    # Remove non-functional scripts
    rm -rf "$pixinsight_dir/bin/lib"

    # Remove broken symbolic links
    find "$pixinsight_dir/library/" -xtype l -delete

    # Patch and wrap the main executable
    install -Dm755 "$pixinsight_dir/bin/PixInsight" "$out/bin/PixInsight"

    # Copy necessary data files
    cp -r "$pixinsight_dir" "$out/opt/"

    # Create desktop entry
    install -Dm444 "$pixinsight_dir/pixinsight.desktop" "$out/share/applications/pixinsight.desktop"
    install -Dm444 "$pixinsight_dir/icons/pixinsight.png" "$out/share/icons/hicolor/512x512/apps/pixinsight.png"

    substituteInPlace $out/share/applications/pixinsight.desktop \
      --replace "/opt/PixInsight/bin/PixInsight" "$out/bin/PixInsight"

    runHook postInstall
  '';

  # https://pixinsight.com/doc/docs/PJSR/PJSR-3.6.4/
  qtWrapperArgs = [
    "--set LC_ALL C"
    "--set PIXINSIGHT_HOME $out/opt/PixInsight"
    "--set QT_STYLE_OVERRIDE Fusion"
    "--add-flags -s=$out/opt/PixInsight"
  ];

  meta = with lib; {
    description = "Scientific image processing program for astrophotography";
    homepage = "https://pixinsight.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ sheepforce ];
  };
})
