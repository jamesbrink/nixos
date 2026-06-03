{
  lib,
  stdenvNoCC,
  installShellFiles,
}:

stdenvNoCC.mkDerivation {
  pname = "create-context-model";
  version = "1.0.0";

  src = ../../scripts/create-context-model.sh;
  dontUnpack = true;

  nativeBuildInputs = [ installShellFiles ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/create-context-model"
    ln -s "$out/bin/create-context-model" "$out/bin/create_context_model.sh"

    installShellCompletion --cmd create-context-model \
      --bash ${./create-context-model.bash} \
      --fish ${./create-context-model.fish} \
      --zsh ${./_create-context-model}

    installShellCompletion --cmd create_context_model.sh \
      --bash ${./create-context-model.bash} \
      --fish ${./create-context-model.fish} \
      --zsh ${./_create-context-model}

    runHook postInstall
  '';

  meta = {
    description = "Create an Ollama model variant with a custom context window";
    license = lib.licenses.mit;
    mainProgram = "create-context-model";
    platforms = lib.platforms.unix;
  };
}
