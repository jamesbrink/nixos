# Source-built text-only Strata engine; never runs upstream setup/install scripts.
{
  lib,
  fetchzip,
  cudaPackages,
  cmake,
  ninja,
  python3,
  makeWrapper,
  curl,
  coreutils,
  bash,
}:
let
  source = fetchzip {
    url = "https://github.com/Niko1221/Strata/archive/6f32ec070f23ced9f50e704d854d775da52591ab.tar.gz";
    hash = "sha256-9jqmV+AbGKiOqW1DvKjqBLVXmJCI9o6WI85QoHj5vBI=";
  };
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
    ]
  );
in
cudaPackages.backendStdenv.mkDerivation {
  pname = "strata";
  version = "0.1.39-6f32ec0";
  src = source;
  # psutil can return None when no block devices are visible in a sandbox.
  patches = [
    ./strata/telemetry-no-disk-counters.patch
    ./strata/huggingface-token-file.patch
  ];
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
    cmake --build . --target strata --parallel "$NIX_BUILD_CORES"
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
    cp strata "$out/bin/strata"
    cp -r "$NIX_BUILD_TOP/source"/{serve,tools,data,docs,LICENSE} "$out/share/strata/"
    makeWrapper ${python}/bin/python "$out/bin/strata-server" \
      --set PYTHONPATH "$out/share/strata" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --add-flags "-m serve.server"
    for tool in iq_pack mtp_fetch mtp_pack mtp_rt; do
      makeWrapper ${python}/bin/python "$out/bin/strata-$tool" \
        --set STRATA_GGUF_PY ${llamaSource}/gguf-py \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --add-flags "$out/share/strata/tools/$tool.py"
    done
    makeWrapper ${bash}/bin/bash "$out/bin/strata-orca-provision" \
      --add-flags ${../scripts/strata-orca-provision.sh} \
      --set STRATA_SHARE "$out/share/strata" \
      --prefix PATH : "${
        lib.makeBinPath [
          curl
          coreutils
        ]
      }:$out/bin"
    runHook postInstall
  '';
  meta = {
    description = "Strata tiered MoE runtime with pinned Orca-compatible packing tools";
    homepage = "https://github.com/Niko1221/Strata";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
