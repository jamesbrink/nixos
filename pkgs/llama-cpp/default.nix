{ lib
, stdenv
, fetchFromGitHub
, cmake
, git
, openblas
, cudaSupport ? false
, cudaPackages ? null
, gcc11
, makeWrapper
, linuxPackages
}:

let
  cudaArch = "89";  # RTX 4090
in
stdenv.mkDerivation rec {
  pname = "llama-cpp";
  version = "b4677";  # Latest release as of 2025-02-09

  src = fetchFromGitHub {
    owner = "ggerganov";
    repo = "llama.cpp";
    rev = "19d3c8293b1f61acbe2dab1d49a17950fd788a4a";  # Latest master commit
    hash = "sha256-s6f6bZxXmbN9YF4MzHGhxz9ynsM6M2e6Jkc5POegdDc=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ cmake git gcc11 makeWrapper ] ++ lib.optionals cudaSupport [
    cudaPackages.cuda_nvcc
  ];

  buildInputs = [ openblas ] ++ lib.optionals cudaSupport [
    cudaPackages.cuda_cudart
    cudaPackages.cuda_cccl
    cudaPackages.libcublas
    cudaPackages.cuda_cudart.lib
    cudaPackages.cuda_cudart.static
    linuxPackages.nvidia_x11
  ];

  runtimeDependencies = lib.optionals cudaSupport [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
    cudaPackages.cuda_nvcc
    cudaPackages.cuda_cccl
    linuxPackages.nvidia_x11
  ];

  cmakeFlags = [
    "-DLLAMA_BLAS=ON"
    "-DLLAMA_BLAS_VENDOR=OpenBLAS"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DLLAMA_NATIVE=OFF"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DLLAMA_STATIC=ON"
    "-DGGML_STATIC=ON"
  ] ++ lib.optionals cudaSupport [
    "-DGGML_CUDA=ON"
    "-DCMAKE_CUDA_ARCHITECTURES=${cudaArch}"
    "-DCUDA_TOOLKIT_ROOT_DIR=${cudaPackages.cuda_cudart}"
    "-DCUDA_CUBLAS_LIBRARY=${cudaPackages.libcublas}/lib/libcublas.so"
    "-DCUDA_CUDART_LIBRARY=${cudaPackages.cuda_cudart}/lib/libcudart.so"
    "-DCUDA_NVCC_EXECUTABLE=${cudaPackages.cuda_nvcc}/bin/nvcc"
    "-DLLAMA_CUDA=ON"
    "-DLLAMA_CUDA_F16=ON"
    "-DLLAMA_CUDA_DMMV=ON"
    "-DLLAMA_CUDA_MMV_Y=ON"
  ];

  env.CUDA_PATH = lib.optionalString cudaSupport "${cudaPackages.cuda_cudart}";
  CXXFLAGS = lib.optionalString cudaSupport "-I${cudaPackages.cuda_cudart}/include";
  
  preConfigure = lib.optionalString cudaSupport ''
    export CUDA_PATH="${cudaPackages.cuda_cudart}"
    export CUDA_HOME="${cudaPackages.cuda_cudart}"
    export EXTRA_LDFLAGS="-L${cudaPackages.cuda_cudart}/lib/stubs -L${cudaPackages.cuda_cudart}/lib64 -L${cudaPackages.libcublas}/lib"
    export CC=${gcc11}/bin/gcc
    export CXX=${gcc11}/bin/g++
    export PATH="${cudaPackages.cuda_nvcc}/bin:$PATH"
    export CUDA_VISIBLE_DEVICES=0
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    # Install binaries
    for f in bin/llama-*; do
      if [ -x "$f" ]; then
        install -Dm755 "$f" "$out/bin/$(basename $f)"
      fi
    done

    # Install additional resources
    cp -r ../examples $out/examples
    cp -r ../prompts $out/prompts
    runHook postInstall
  '';

  postFixup = lib.optionalString cudaSupport ''
    for f in $out/bin/llama-*; do
      patchelf --set-rpath "${lib.makeLibraryPath ([
        stdenv.cc.cc.lib
      ] ++ runtimeDependencies)}" "$f"

      wrapProgram "$f" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeDependencies}" \
        --set CUDA_VISIBLE_DEVICES "0"
    done
  '';

  meta = with lib; {
    description = "Port of Facebook's LLaMA model in C/C++";
    homepage = "https://github.com/ggerganov/llama.cpp";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ ];
  };
}
