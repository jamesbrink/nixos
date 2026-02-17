{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "gogcli";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "gogcli";
    tag = "v${version}";
    hash = "sha256-hJU40ysjRx4p9SWGmbhhpToYCpk3DcMAWCnKqxHRmh0=";
  };

  vendorHash = "sha256-WGRlv3UsK3SVBQySD7uZ8+FiRl03p0rzjBm9Se1iITs=";

  subPackages = [ "cmd/gog" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  meta = {
    description = "Google Workspace CLI for Gmail, Calendar, Drive, Contacts, and more";
    homepage = "https://github.com/steipete/gogcli";
    license = lib.licenses.mit;
    mainProgram = "gog";
  };
}
