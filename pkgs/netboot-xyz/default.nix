{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "netboot-xyz";
  version = "2.0.87";

  src = fetchurl {
    url = "https://github.com/netbootxyz/netboot.xyz/releases/download/${version}/netboot.xyz.kpxe";
    sha256 = "115cacqv2k86wifzymqp1ndw5yx8wvmh2zll4dn2873wdvfxmlcl";
  };

  efi = fetchurl {
    url = "https://github.com/netbootxyz/netboot.xyz/releases/download/${version}/netboot.xyz.efi";
    sha256 = "0zqqq8d10gn9hy5rbxg5c46q8cjlmg6kv7gkwx3yabka53n7aizj";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp $src $out/netboot.xyz.kpxe
    cp $efi $out/netboot.xyz.efi
  '';

  meta = with lib; {
    description = "Network bootable operating system installer based on iPXE";
    homepage = "https://netboot.xyz";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
