# Source-built text-only Strata engine plus the terminal monitor (strata_cli);
# never runs upstream setup/install scripts or the self-updater.
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
    url = "https://github.com/Niko1221/Strata/archive/ffa80d73133ea5c548aefe57889a16e8085a938f.tar.gz";
    hash = "sha256-cIBcdKRYVH78bu4sElF0XK/wedcLTK8tu12c0Alzlw8=";
  };
  # Must match upstream third_party/ggml/VERSION.txt.
  llamaSource = fetchzip {
    url = "https://github.com/ggml-org/llama.cpp/archive/3cf03257f219afbe7334045ff7c6a06ac68c627d.tar.gz";
    hash = "sha256-SRGoXa+4ACBCB3eaG9XFYhMN1i0FyPEy9Rrer+dFGYI=";
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
  version = "0.2.10";
  src = source;
  patches = [ ./strata/huggingface-token-file.patch ];
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
  cmakeFlags = [
    "-DSTRATA_ENABLE_CUDA=ON"
    "-DSTRATA_PORTABLE=ON"
    "-DSTRATA_BUILD_TESTS=OFF"
    "-DCMAKE_CUDA_ARCHITECTURES=89"
    "-DCMAKE_CUDA_COMPILER=${cudaPackages.cuda_nvcc}/bin/nvcc"
    "-DSTRATA_GGML_DIR=${llamaSource}"
  ];
  buildPhase = ''
    runHook preBuild
    # strata_kq: K-quant prompt kernels, dlopen'd from the engine's own folder
    # only with STRATA_MMQ_KQ=1.
    cmake --build . --target strata strata_kq --parallel "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cd "$NIX_BUILD_TOP/source"
    export STRATA_GGUF_PY=${llamaSource}/gguf-py
    export PYTHONDONTWRITEBYTECODE=1
    ${python}/bin/python -m unittest discover -s tools -p test_iq_pack.py
    ${python}/bin/python -m unittest serve.test_server
    ${python}/bin/python ${./strata/test-mtp-auth.py}
    cd "$NIX_BUILD_TOP/source/build"
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share/strata"
    cp strata libstrata_kq.so "$out/bin/"
    cp -r "$NIX_BUILD_TOP/source"/{serve,tools,data,docs,strata_cli,strata_control,strata.py,LICENSE} "$out/share/strata/"
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
        --set STRATA_GGUF_PY ${llamaSource}/gguf-py \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --add-flags "$out/share/strata/tools/$tool.py"
    done
    runHook postInstall
  '';
  # strata-vision builds from the same pinned Strata and llama.cpp sources.
  passthru = { inherit source llamaSource; };
  meta = {
    description = "Strata tiered MoE runtime with pinned Orca-compatible packing tools and terminal monitor";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
