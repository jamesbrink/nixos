# Core Vision

Our goal is to keep every personal and lab host—macOS, NixOS, containers, and cloud nodes—on a single reproducible track. The entire fleet should rebuild from bare metal using this repo alone, with declarative Nix flakes defining operating systems, Home Manager layers, secrets, and utilities. Modularity matters: hosts compose profiles, profiles compose modules, and modules encapsulate services or apps so we can mix, match, and audit changes quickly.

Continuous reloadability is non‑negotiable. Any host must be safe to reconfigure on demand (`darwin-rebuild`, `nixos-rebuild`, `deploy`) and to roll back if an experiment fails. Infrastructure-as-code discipline keeps drift out: every package, theme, and workflow (Hyprland, Yabai BSP, Ghostty, Neovim, VSCode, asset sync) lives here and can be reasoned about, linted, and tested.

This vision also includes agent collaboration. Humans, GPT-based agents, and CI should share context through these docs, TODOs, and clean scripts, so new ideas—like the upcoming Python `themectl` helper—slot into the same reproducible story without bespoke hacks.
