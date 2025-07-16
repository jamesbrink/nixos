# PixInsight overlay
# Makes our custom PixInsight package available in the package set
final: prev: {
  pixinsight = final.callPackage ../pkgs/pixinsight { };
}
