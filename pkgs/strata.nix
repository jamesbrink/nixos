# Source-built Strata engine, its Python server and tools, and the terminal
# monitor (strata_cli); never runs upstream setup/install scripts or the
# self-updater. Since 0.2.16 the tree is split into engine/ (C++) and
# terminal/ (Python), and ggml is vendored, so nothing else is fetched.
{
  lib,
  fetchzip,
  cudaPackages,
  cmake,
  ninja,
  python3,
  makeWrapper,
}:
let
  source = fetchzip {
    url = "https://github.com/Niko1221/Strata/archive/64524fb9fc82222ddce554c0643b64f056ec8366.tar.gz";
    hash = "sha256-g6TO9zC2jt41B5oADYrypIrXpb73/QzXmqjUuzBe9E4=";
  };
  python = python3.withPackages (
    ps: with ps; [
      numpy
      regex
      jinja2
      pyyaml
      tqdm
      requests
      pillow
      psutil
      certifi
      truststore
      # Terminal monitor (`strata-cli monitor`) only.
      textual
      rich
    ]
  );
in
cudaPackages.backendStdenv.mkDerivation {
  pname = "strata";
  version = "0.2.16";
  src = source;
  nativeBuildInputs = [
    cmake
    ninja
    makeWrapper
    cudaPackages.cuda_nvcc
    python
  ];
  buildInputs = [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];
  cmakeDir = "../engine";
  cmakeFlags = [
    "-DSTRATA_ENABLE_CUDA=ON"
    "-DSTRATA_PORTABLE=ON"
    "-DSTRATA_BUILD_TESTS=OFF"
    "-DCMAKE_CUDA_ARCHITECTURES=89"
    "-DCMAKE_CUDA_COMPILER=${cudaPackages.cuda_nvcc}/bin/nvcc"
  ];
  buildPhase = ''
    runHook preBuild
    cmake --build . --target strata --parallel "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cd "$NIX_BUILD_TOP/source/terminal"
    export PYTHONDONTWRITEBYTECODE=1
    ${python}/bin/python -m unittest discover -s tools -p test_iq_pack.py
    ${python}/bin/python -m unittest serve.test_server
    cd "$NIX_BUILD_TOP/source/build"
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/strata"
    cp strata "$out/bin/"
    cp -r "$NIX_BUILD_TOP/source"/terminal/{serve,tools,data,strata_cli,strata_control,strata.py} \
      "$NIX_BUILD_TOP/source"/{docs,LICENSE} "$out/share/strata/"
    makeWrapper ${python}/bin/python "$out/bin/strata-server" \
      --set PYTHONPATH "$out/share/strata" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --add-flags "-m serve.server"
    # Upstream's `strata` terminal command; renamed because bin/strata is the
    # engine. STRATA_NO_HANDOVER stops it exec'ing a self-updated Control.
    makeWrapper ${python}/bin/python "$out/bin/strata-cli" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --set STRATA_NO_HANDOVER 1 \
      --add-flags "$out/share/strata/strata.py"
    for tool in iq_pack mtp_fetch mtp_pack mtp_rt; do
      makeWrapper ${python}/bin/python "$out/bin/strata-$tool" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --add-flags "$out/share/strata/tools/$tool.py"
    done
    runHook postInstall
  '';
  # strata-vision builds from the same pinned source.
  passthru = { inherit source; };
  meta = {
    description = "Strata tiered MoE runtime with pinned Orca-compatible packing tools and terminal monitor";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
