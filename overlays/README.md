# Overlays

This directory contains Nix overlays used to customize packages.

## aider-no-texlive.nix

This overlay modifies the `aider-chat` package to remove its `pypandoc` dependency, which prevents pulling in the large texlive distribution. The overlay:

1. Filters out `pypandoc` from the propagated build inputs
2. Patches Python files to remove pypandoc imports and usage
3. Disables any tests that require pypandoc

This significantly reduces the closure size by avoiding the multi-gigabyte texlive dependency.
