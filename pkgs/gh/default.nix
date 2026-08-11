{
  lib,
  fetchFromGitHub,
  buildGo126Module,
  installShellFiles,
  stdenv,
  versionCheckHook,
  makeWrapper,
}:

buildGo126Module (finalAttrs: {
  pname = "gh";
  version = "2.97.0";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "cli";
    repo = "cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-yG3bo7YVs1Q//9PePusU0m4TilujQMxI4Faz26iAb5g=";
  };

  vendorHash = "sha256-XeXHMEhe1ZVWtenyYIzaYjNovaArvI0xBRWVabUF9KU=";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  # Use the Makefile so gh embeds the same version metadata as upstream builds.
  buildPhase = ''
    runHook preBuild
    make GO_LDFLAGS="-s -w -X github.com/cli/cli/v${lib.versions.major finalAttrs.version}/internal/build.Date=nixpkgs" GH_VERSION=${finalAttrs.version} bin/gh ${lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) "manpages"}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    installBin bin/gh
    wrapProgram $out/bin/gh \
      --set-default GH_TELEMETRY false
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installManPage share/man/*/*.[1-9]

    installShellCompletion --cmd gh \
      --bash <($out/bin/gh completion -s bash) \
      --fish <($out/bin/gh completion -s fish) \
      --zsh <($out/bin/gh completion -s zsh)
  ''
  + ''
    runHook postInstall
  '';

  # Most upstream tests require network access.
  doCheck = false;

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "GitHub CLI tool";
    homepage = "https://cli.github.com/";
    changelog = "https://github.com/cli/cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "gh";
    platforms = lib.platforms.unix;
  };
})
