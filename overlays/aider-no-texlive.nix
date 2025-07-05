# Overlay to build aider-chat without pypandoc to avoid pulling in texlive
final: prev: {
  # Override aider-chat directly in the package set
  aider-chat = prev.aider-chat.overridePythonAttrs (oldAttrs: {
    # Remove pypandoc from dependencies to avoid texlive
    propagatedBuildInputs = builtins.filter (
      dep: !(prev.lib.hasInfix "pypandoc" (dep.pname or ""))
    ) oldAttrs.propagatedBuildInputs;

    # Add a patch phase to remove pypandoc imports if needed
    postPatch =
      (oldAttrs.postPatch or "")
      + ''
        # Remove pypandoc imports and usage
        find . -name "*.py" -type f -exec sed -i \
          -e '/import pypandoc/d' \
          -e '/from pypandoc/d' \
          -e 's/pypandoc\.[a-zA-Z_]*([^)]*)/""/g' \
          {} +
      '';

    # Disable tests that might require pypandoc
    disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
      "test_pandoc"
      "test_pypandoc"
    ];
  });
}
