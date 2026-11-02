# Bun ahead of nixpkgs: oh-my-pi's installer requires >= 1.4.4, while nixpkgs
# stable has 1.3.13 and nixos-unstable 1.4.2. Drop once nixpkgs catches up.
final: prev: {
  bun = prev.bun.overrideAttrs (_: rec {
    version = "1.4.4";
    src = final.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
      # From the release's SHASUMS256.txt.
      sha256 = "bf8ccbfb2b0b80159e0f9a6d15c55317add8077534dbc6130a3edb52fccb395c";
    };
  });
}
