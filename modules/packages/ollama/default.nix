{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  cmake,
  cudaPackages,
  acceleration ? "cuda",
}:

let
  pname = "ollama-cuda";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v${version}";
    hash = "sha256-BXRCTBc+2LmY+FIRYTwuazWAhBErITbF70ihL24tqWw=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-mqaWq7wYnZi+Kyj7qawhM3jBBdYH0CEO4lwZKNQkgG8=";

  cudaPackage = cudaPackages.cudatoolkit;

  useCuda = acceleration == "cuda";

in
buildGoModule {
  inherit
    pname
    version
    src
    vendorHash
    ;

  nativeBuildInputs = [
    cmake
    makeWrapper
  ];

  buildInputs = lib.optionals useCuda [
    cudaPackage
  ];

  CGO_ENABLED = "1";

  tags = lib.optionals useCuda [ "cuda" ];

  doCheck = false;

  modVendorFlags = [ "-modcacherw" ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/ollama/ollama/version.Version=${version}"
    "-X=github.com/ollama/ollama/server.mode=release"
  ];

  postPatch = ''
    substituteInPlace version/version.go --replace 0.0.0 '${version}'
  '';

  preBuild = ''
    export OLLAMA_SKIP_PATCHING=true
    ${lib.optionalString useCuda ''
      export CMAKE_ARGS="-DLLAMA_CUBLAS=ON"
    ''}
  '';

  postInstall = lib.optionalString useCuda ''
    wrapProgram $out/bin/ollama \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ cudaPackage ]}"
  '';

  meta = with lib; {
    description =
      "Get up and running with large language models locally"
      + (lib.optionalString useCuda " (with CUDA support)");
    homepage = "https://github.com/ollama/ollama";
    changelog = "https://github.com/ollama/ollama/releases/tag/v${version}";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "ollama";
  };
}
