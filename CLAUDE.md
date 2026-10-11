# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, Test, and Deploy Commands

Enter the dev shell first: `nix develop` (or `direnv allow`) — sets `NIXPKGS_ALLOW_UNFREE=1` and exposes all helpers.

| Command                   | Purpose                                             |
| ------------------------- | --------------------------------------------------- |
| `format`                  | Run treefmt (nixfmt + prettier + ruff + shellcheck) |
| `check`                   | Run `nix flake check --impure`                      |
| `build <host>`            | Build host (auto-detects NixOS vs Darwin)           |
| `deploy <host>`           | Production deployment                               |
| `deploy-test <host>`      | Dry-run deployment (no activation)                  |
| `deploy-local <host>`     | Build locally, push to remote (for low-RAM targets) |
| `deploy-all`              | Parallel deploy to all hosts with summary report    |
| `health-check <host>`     | Post-deploy service verification                    |
| `show-generations <host>` | List rollback points                                |
| `rollback <host>`         | Revert to previous generation                       |
| `show-hosts`              | List all available host names                       |

All devshell commands (including the ones below) require `--impure` under the hood since `NIXPKGS_ALLOW_UNFREE=1` is set. When running raw `nix build` or `nix flake check` outside the devshell, pass `--impure`.

**Secrets management:**

- `secrets-edit <path>` — edit/create encrypted secret (auto-adds to secrets.nix)
- `secrets-rekey` — re-encrypt all secrets with current recipients
- `secrets-verify` — check all secrets decrypt correctly
- `scan-gitleaks` or `scan-secrets --all` — scan for leaked credentials before push

**Kubernetes (Rancher + monitoring):**

- `deploy-k8s rancher` — bootstrap/refresh Rancher + Grafana proxy

## Architecture Overview

### External Flake Wiring Pattern

When adding an external flake to a host, three things must be wired in `flake.nix`:

1. Add the flake input (e.g., `invokeai.url = "github:jamesbrink/InvokeAI/feature/nix-flake"`)
2. Add `<flake>.nixosModules.default` (or `darwinModules.default`) to the host's `modules` list
3. Add `<flake>.overlays.default` to the host's `nixpkgs.overlays` list

Then configure the service in the host's `default.nix`. See hal9000 (comfyui, invokeai, ai-toolkit, zerobyte, mold) and bender (invokeai, ai-toolkit) as reference.

### Key Patterns

**Host files** should only stitch profiles and host-specific overrides. Business logic belongs in modules or `scripts/`.

**Profiles** aggregate modules into roles: `server` (NixOS servers), `desktop` (NixOS with GUI), `darwin` (full macOS workstation), `darwin-slim` (headless macOS), `n100` (mini-PC cluster nodes), `keychron` (keyboard config). Darwin hosts use `home-manager-unstable` (follows `nixos-unstable`); NixOS hosts use stable `home-manager` (follows `nixpkgs`).

**specialArgs** passed to every host include `inputs`, `agenix`, `secretsPath`, and `hotkeysBundle`. Some hosts also get `self`, `claude-desktop`, `unstablePkgs`, and external flake inputs (e.g., `comfyui-nix`, `mold`). These are defined per-host in `flake.nix` and available in any imported module.

**Overlays** (`overlays/`) provide `unstablePkgs` and custom derivations (PixInsight, gogcli). Access via `pkgs.unstablePkgs.<package>`.

**Secrets** live in `secrets/` as `.age` files encrypted via agenix. Recipients are tracked in `secrets/secrets.nix`. Hosts decrypt using their SSH host key (`/etc/ssh/ssh_host_ed25519_key`).

**Network Infrastructure** is managed via the `mikrotik-terraform/` submodule (private repo with secrets). It configures the MikroTik CRS310-8G+2S+ router:

- Network: `10.70.100.0/24` with domain `home.urandom.io`
- DHCP static leases, DNS records, WireGuard VPNs, PXE boot
- Commands: `cd mikrotik-terraform && nix develop`, then `tf-plan` / `tf-apply`
- See `mikrotik-terraform/README.md` for full documentation

**Theme system** (`scripts/themectl/`) is a Python CLI used on Darwin and on the legacy Hyprland session (alienware); hal9000 disables it in favour of Omarchy's theming. It:

- Reads theme metadata from `modules/themes/lib.nix` and color definitions in `modules/themes/colors/`
- Syncs wallpapers from `external/omarchy/` submodule
- Rewrites configs for Alacritty, Ghostty, VSCode, Neovim, tmux, btop
- Drives yabai BSP/native mode toggle on macOS

### Desktop: Omarchy via nixarchy (hal9000)

hal9000 (NixOS 26.05) autologins into the "Omarchy" session from the `nixarchy` flake input (Omarchy v4, Quickshell shell), configured in `profiles/desktop/nixarchy.nix`. Overrides there: keep SDDM, pin `boot.kernelPackages = pkgs.linuxPackages` (nixarchy defaults to latest), keep nixpkgs Hyprland, disable `services.nixi`, and turn off the legacy shell from `modules/home-manager/hyprland` (Waybar, Mako, hypridle, swayosd, themectl, tray autostarts). That module still loads for tmux/terminals and for alienware's legacy session. Wi-Fi uses `modules/wifi-networkmanager.nix` (NetworkManager + iwd, wireless only; wired and `br0` stay on networkd).

- The video screensaver runs as Omarchy's screensaver: the profile overrides `omarchy-launch-screensaver` to exec `hypr-launch-screensaver`, and mpv uses Omarchy's window class `org.omarchy.screensaver`.
- Omarchy-owned, mutable user files (not in git): `~/.config/hypr/*.lua` (e.g. `monitors.lua` pins DP-1 at 7680x2160@120) and `~/.config/omarchy/shell.toml` (`[font] base-size = 24` doubles the bar/menus).
- Live debugging: copy `PATH`, `OMARCHY_PATH`, `WAYLAND_DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` from the running `quickshell` process, then drive panels with `omarchy-shell <target> <method>`. `hyprctl dispatch` takes Lua (`hl.dsp.*`) in this session.
- Hyprland 0.53+ config (legacy session) uses `match:` window rules and `layoutmsg` for `togglesplit`/`splitratio`; HM `configType = "hyprlang"` is pinned because 26.05 defaults to Lua.

### Container pruning

`modules/container-prune.nix` (`local.containerPrune.enable`, on hal9000, alienware and the n100s) runs weekly `system prune --all --filter until=336h` for Docker, system Podman, and each user's rootless Podman store (a `systemd.user` timer). Running containers, their images and volumes are kept; tune with `local.containerPrune.olderThanDays`.

### PostgreSQL 17 (hal9000)

Plain upstream `services.postgresql` for misc dev work: port 5432, trust auth from localhost/LAN/Tailscale, data on the `storage-fast/postgresql` ZFS dataset at `/var/lib/postgresql`. Connect with `psql -h hal9000` (superuser `jamesbrink` or `postgres`).

### LLM serving (hal9000)

`services.llama-swap` on port 8080 is the OpenAI-compatible endpoint (`http://hal9000:8080/v1`): it launches a `llama-server` per requested model and unloads after `ttl`. GGUFs live on the `storage-fast/llm` dataset (`/storage-fast/llm/models`, recordsize=1M). Ternary Bonsai 2 models need the PrismML llama.cpp fork (`overlays/llama-cpp-prism.nix`, input `llama-cpp-prism`, built for sm_89 only); stock GGUFs can use `pkgs.llama-cpp`. Models (no aliases): `bonsai-2-27b` (PQ2_0 + MTP bundle, 320K q4_0 KV pool shared by 8 slots, 262K per conversation) and `qwen3.8-27b` (UD-Q4_K_M + MTP draft, 64K, 2 slots). Only one fits the 4090 at a time, so switching models reloads and drops prompt caches. Both use MTP speculative decoding (`--spec-type draft-mtp`). Add a model by adding an entry under `services.llama-swap.settings.models`. Measured sizing notes live in the comment above the service in `hosts/hal9000/default.nix`.

Hal9000 explicitly sets `services.llama-swap.listenAddress = "0.0.0.0"` with `openFirewall = true` for LAN/Tailscale clients. Upstream defaults to `localhost`; opening the firewall alone does not make the listener reachable. If remote models disappear, compare `curl http://hal9000:8080/v1/models` with the loopback URL on Hal9000 before changing client model configuration. This endpoint has no API authentication; keep it on trusted networks, not the public internet.

### Bonsai 2 serving (bender)

`services.bonsai2` exposes `http://bender:8080/v1` with model ID `bonsai-2-27b`. It uses the PrismML llama.cpp fork's Metal backend, official PQ2_0 weights and Q8_0 vision projector, one 16K F16-KV slot, and a ten-minute `llama-swap` idle unload. The shared overlay remains CUDA sm_89-only on Linux and selects native Metal on aarch64-darwin. See [docs/bonsai2-bender.md](docs/bonsai2-bender.md) for hardware sizing, pinned model provenance, tuning, security, and smoke commands.

### Orca Flash Next shared endpoint (hal9000)

`services.strata-orca` adds `orcarouter-qwen3.8-flash-next-uncensored-iq3_xxs` to the existing llama-swap `:8080/v1` endpoint. llama-swap owns the Strata child, loopback backend, readiness, exclusive model switching, idle unload and process-tree cleanup; there is no independent service. See [docs/strata-orca.md](docs/strata-orca.md) for pinned IQ3_XXS provenance, provisioning, RAM/GPU guards, tests and benchmark commands. Publisher access is granted; authenticated immutable shard verification, compatibility packing and matching MTP provisioning completed on 2026-10-05. HAL9000 explicitly selects bounded mmap with a 24 GiB expert budget, 8 GiB headroom and 36 GiB available-memory guard; full resident mode retains its 56 GiB guard. HAL permits walker, chrome, mpv and swayosd-server desktop compute within 1024 MiB aggregate, requires 20,480 MiB free VRAM, and explicitly reserves 2 GiB from the expert cache. Concurrent Mold generation is unsupported. Real shared-endpoint inference and phased tuning have measured screening evidence in [docs/benchmarks/orca-20261005.md](docs/benchmarks/orca-20261005.md) and byte-identical raw reports. Selected FP16/32K/prefill 2048/23-worker/T4/suffix0 settings are deployed from independently reviewed commit `7985f2c`, closure `hfsq6wn...`, with all 23 encrypted-input and runtime metadata checks passing. Shared API/tool/lifecycle UAT, actual production benchmark and restored desktop/Mold cold-admission acceptance completed; actual cached native medians were18.98/13.29/32.45tok/s for code/prose/retrieval, slower than warmer screening runs. All five services were restored, all models left unloaded, and port18081closed; prior interactive desktop applications were not automatically resumed. historical non-activating rehearsal results are labeled separately. `strata-orca-provision` defaults to a plan and supports a root-readable HF token file without exposing credentials.

## Coding Standards

**Nix**: Two-space indentation, sorted attribute sets, formatted by `nixfmt`. Prefer upstream modules before writing custom logic.

**Bash**: `#!/usr/bin/env bash` with `set -euo pipefail`. Checked by `shellcheck` (with `-x -e SC1091,SC2029`).

**Python** (`scripts/themectl/`): Type hints everywhere, Ruff for lint/format, BasedPyright for type checking, pytest for tests. Keep files under 800 lines.

**Commits**: Conventional Commits scoped to paths (e.g., `feat(hosts/halcyon): enable yabai toggle`).

## Pre-Push Checklist

1. `format` — run treefmt
2. `nix flake check --impure` — validate all hosts build
3. `deploy-test <host>` — for each affected host
4. `scan-gitleaks` or `scan-secrets --all` — no leaked credentials
5. Stage relevant files before `deploy` to avoid "missing file" failures on remote builds

## Submodules

| Path                  | Purpose                                    | Contains Secrets      |
| --------------------- | ------------------------------------------ | --------------------- |
| `secrets/`            | Agenix-encrypted secrets (.age files)      | Yes                   |
| `mikrotik-terraform/` | MikroTik router IaC (DHCP, DNS, VPN, PXE)  | Yes (tfvars, tfstate) |
| `external/omarchy/`   | Upstream Omarchy v4 (reference, themectl)  | No                    |

**Keeping submodules in sync:** Private submodules (`secrets/`, `mikrotik-terraform/`) must be pushed before the main repo. This is enforced by:

1. Git config `push.recurseSubmodules = on-demand` — auto-pushes submodules
2. Pre-push hook — blocks push if submodules have unpushed commits

To install hooks after cloning: `./scripts/git-hooks/install-hooks.sh`

## GitHub Actions

See `docs/github-actions.md` for troubleshooting, including force-cancelling runs stuck in `queued` after runner-label fixes.

## Package Lookups

Use the `mcp__nixos__nix` MCP tool as the **first choice** for checking package availability, versions, and options across channels. It supports `search`, `info`, `options`, and `flake-inputs` actions against nixos, home-manager, darwin, and other sources. Fall back to `nix eval` or `nix search` only when the MCP tool doesn't cover the query.

## Reference Docs

- `VISION.md` — fleet goals and guardrails
- `DESIGN.md` — repository layout and ownership boundaries
- `TECH_STACK.md` — supported platforms, languages, tooling
- `STANDARDS.md` — testing, documentation, language-specific requirements
- `HOTKEYS.md` — keybinding reference (Yabai, Hyprland, tmux, Neovim)
- `SECRETS.md` — secrets lifecycle and Kubernetes integration
- `mikrotik-terraform/README.md` — network infrastructure management
