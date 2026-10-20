# Strata's image encoder (llama.cpp mtmd + an mmproj file), as upstream setup
# builds it: tools/vision against the engine's pinned llama.cpp, CUDA sm_89.
{
  strata,
  cudaPackages,
  cmake,
  ninja,
  autoAddDriverRunpath,
}:
cudaPackages.backendStdenv.mkDerivation {
  pname = "strata-vision";
  inherit (strata) version;
  src = strata.passthru.source;
  nativeBuildInputs = [
    cmake
    ninja
    cudaPackages.cuda_nvcc
    autoAddDriverRunpath
  ];
  buildInputs = with cudaPackages; [
    cuda_cccl
    cuda_cudart
    libcublas
  ];
  cmakeDir = "../tools/vision";
  cmakeFlags = [
    "-DLLAMA_DIR=${strata.passthru.llamaSource}"
    "-DSTRATA_VISION_CUDA=ON"
    "-DSTRATA_PORTABLE=ON"
    "-DCMAKE_CUDA_ARCHITECTURES=89"
    "-DCMAKE_CUDA_COMPILER=${cudaPackages.cuda_nvcc}/bin/nvcc"
  ];
  buildPhase = ''
    runHook preBuild
    cmake --build . --target strata-vision --parallel "$NIX_BUILD_CORES"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/strata-vision "$out/bin/strata-vision"
    runHook postInstall
  '';
  meta = strata.meta // {
    description = "Strata image encoder (llama.cpp mtmd) for mmproj vision projectors";
    mainProgram = "strata-vision";
  };
}
