# TODO

## Home-Manager Configuration Validation Summary

After reviewing the home-manager settings across all modules, here are my findings:

### ✅ Correct Usage Patterns Found:

1. **Module Organization**: Clean separation into `shell`, `editor`, and `cli-tools` modules
2. **Cross-Platform Support**: Proper use of `lib.optionals` and `pkgs.stdenv.isDarwin/isLinux` checks
3. **Shell Integration**: Correct use of `enableZshIntegration`, `enableBashIntegration` flags
4. **SSH Configuration**: Proper use of `programs.ssh.includes` for modular SSH config
5. **Git Configuration**: Correctly using `programs.git` with delta integration
6. **Terminal Apps**: Alacritty, tmux, starship all properly configured
7. **Editor**: Neovim with LSP, treesitter, and plugins properly set up

### ⚠️ Minor Issues/Recommendations:

1. **SSH Includes Path**: Using `${config.home.homeDirectory}` and `${homeDir}` inconsistently in `jamesbrink-shared.nix:41-43`. Should use `config.home.homeDirectory` consistently.

2. **Missing `nixpkgs.config.allowUnfree`**: The Darwin user configuration (`jamesbrink-darwin.nix`) doesn't set `nixpkgs.config.allowUnfree = true` in home-manager, though it's set at the system level in flake.nix.

3. **History Size Values**: Using extremely large numbers (`999999999999`) for zsh history instead of `-1` or `null` for unlimited.

4. **Eza Integration**: Explicitly disabled (`enableZshIntegration = false`) to avoid conflicts with custom aliases - this is correct but worth noting.

### ✅ No Deprecated Options Found:

All home-manager options are using current, supported syntax for the 25.05 release.

### ✅ Proper Type Usage:

All option types match expected values (strings, booleans, lists, attribute sets).

The configuration is well-structured and follows home-manager best practices with only minor improvements possible.