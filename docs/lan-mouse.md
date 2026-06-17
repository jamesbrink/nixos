# lan-mouse — software KVM (keyboard/mouse sharing)

Share one keyboard + mouse between **halcyon** (Mac, aarch64-darwin) and **hal9000**
(NixOS, Hyprland/Wayland). Push the cursor off a screen edge and it — plus the keyboard —
follows onto the other machine. hal9000 sits physically to the **left** of halcyon.

- **halcyon** = the machine with the physical keyboard/mouse (the "sender"/source).
- **hal9000** = the machine being controlled (the "receiver"/sink, injects input into Hyprland).

## Why v0.11.0 from the upstream flake (not the nixpkgs package)

nixpkgs (both 25.11 and unstable, as of mid-2026) ships **lan-mouse 0.10.0** (released
2024-11-07). On a wlroots receiver like Hyprland, 0.10.0 **does not forward modifier keys**
(Ctrl/Shift/Alt/Super) from a non-`layer-shell` sender — i.e. from a Mac. The fix
([PR #238](https://github.com/feschber/lan-mouse/pull/238), merged 2025-01-24) first ships in
**v0.11.0** (2026-06-12), which nixpkgs has not picked up yet. So we pin the upstream flake:

```nix
# flake.nix
lan-mouse.url = "github:feschber/lan-mouse/v0.11.0";
lan-mouse.inputs.nixpkgs.follows = "nixpkgs";
```

The flake exposes packages for all our systems (incl. `aarch64-darwin`) and a home-manager
module (`programs.lan-mouse`). When nixpkgs catches up to ≥0.11.0 this pin can be revisited.

## How it's wired

| Piece                                              | File                                                    |
| -------------------------------------------------- | ------------------------------------------------------- |
| Flake input (v0.11.0)                              | `flake.nix`                                             |
| Shared HM module (config + per-host gating)        | `modules/home-manager/lan-mouse.nix`                    |
| Import on hal9000 (+ upstream HM module)           | `users/regular/jamesbrink-linux.nix` (desktop imports)  |
| Import on halcyon (+ upstream HM module)           | `users/regular/jamesbrink-darwin.nix`                   |
| Firewall (Tailscale already trusted; LAN fallback) | `hosts/hal9000/default.nix` (`allowedUDPPorts += 4242`) |

`modules/home-manager/lan-mouse.nix` self-gates with `osConfig.networking.hostName`, so it is a
no-op on every host except halcyon/hal9000. The upstream `programs.lan-mouse` module is imported
at the **call site** (using the `inputs`/`effectiveInputs` closure), not inside the shared
module — importing it via a module arg inside `imports` triggers infinite recursion.

The HM module creates a **systemd user service** on Linux (`WantedBy=graphical-session.target`,
so it starts with the Hyprland session) and a **launchd agent** on macOS, both running
`lan-mouse daemon`, and writes `~/.config/lan-mouse/config.toml` from `programs.lan-mouse.settings`.

## Network path: Tailscale

halcyon (`192.168.0.x`) and hal9000 (`192.168.1.x`) are on **isolated LAN subnets** — they
cannot reach each other directly. Their only working path is **Tailscale** (direct connection,
~30 ms), so peers are addressed by their stable Tailscale IPs in the module:

- halcyon `100.80.133.72`, hal9000 `100.123.198.98`.

Transport is UDP **4242**, DTLS-encrypted. hal9000's firewall already trusts `tailscale0`, so no
firewall change is strictly required; `allowedUDPPorts += 4242` is there only so a future
same-LAN move keeps working. (Note: hal9000's MagicDNS may resolve `halcyon` to a stale
duplicate node — that's why IPs are pinned explicitly. `tailscale ip -4` on each host is the
source of truth.)

> Latency is Tailscale-direct (~30 ms), not LAN-local (~1 ms). Fine in practice, but putting both
> machines on the same L2 segment would make the cursor snappier.

## Authorization: the fingerprint bootstrap (needed when adding a peer)

Peers authorize each other by **TLS certificate fingerprint** (SHA-256). lan-mouse generates its
cert (`~/.config/lan-mouse/lan-mouse.pem`) on first run, so fingerprints aren't known until then.
Because `config.toml` is a **read-only Nix symlink**, lan-mouse's runtime "authorize" can't
persist (it logs `failed to write config: Read-only file system` — harmless) — so fingerprints
**must** be set declaratively in the module's `authorized_fingerprints`.

To add or re-bootstrap a peer:

1. Deploy with the peer in `clients` but its fingerprint not yet in the _other_ host's
   `authorized_fingerprints`. First run generates each host's cert.
2. Compute each host's fingerprint (note: **hal9000 has no `openssl`**, so read its pem and
   compute on a host that does, e.g. the Mac):
   ```bash
   # local host with openssl:
   openssl x509 -in ~/.config/lan-mouse/lan-mouse.pem -noout -fingerprint -sha256 \
     | sed 's/.*=//' | tr 'A-F' 'a-f'
   # a remote Linux host (no openssl there):
   ssh HOST 'cat ~/.config/lan-mouse/lan-mouse.pem' \
     | openssl x509 -noout -fingerprint -sha256 | sed 's/.*=//' | tr 'A-F' 'a-f'
   ```
   This is the standard WebRTC-DTLS cert fingerprint lan-mouse expects (lowercase, colon-hex).
3. Put **each host's fingerprint into the _other_ host's** `authorized_fingerprints` in
   `modules/home-manager/lan-mouse.nix`, then redeploy both. After a fresh daemon start they
   authorize from the file — confirm with `lan-mouse cli list`.

## macOS permissions (halcyon) — required, manual, one-time

macOS won't let the daemon capture input until you grant **both** TCC permissions to the
lan-mouse binary. Find the binary path with `readlink ~/.nix-profile/bin/lan-mouse`, then in
**System Settings → Privacy & Security** add it to:

- **Accessibility** (`+` → `⌘⇧G` → paste the `/nix/store/...-lan-mouse-*/bin/lan-mouse` path → enable)
- **Input Monitoring** (same path — needed for keyboard/modifier capture)

Then restart the agent so it picks up the grant:

```bash
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.lan-mouse"
```

> **Caveat:** the grant is tied to the Nix store path, so **bumping the lan-mouse version means
> re-granting** both permissions. If that churn becomes annoying, switch the Mac to lan-mouse's
> signed **menubar `.app`** as a Login Item (set `programs.lan-mouse.launchd = false` and install
> the `.app`); the `.app` has a stable path and cleaner TCC. There is no Homebrew cask.

## Using it

- Push the cursor off halcyon's **left** edge → it appears on hal9000. Off hal9000's **right**
  edge → back to halcyon.
- **Release chord:** tap **A + S + D + F** together to snap control back to the local machine.
- hal9000 must have an **active Hyprland session** (the receiver injects into the live session;
  hal9000 has no autologin, so it must be logged in at the console).

**Toggle crossing off/on** without editing Nix or stopping the daemon — run on the machine you
send _from_ (halcyon, where hal9000 is client `id 0` per `lan-mouse cli list`):

```bash
lan-mouse cli deactivate 0   # OFF: cursor stays on halcyon, won't cross
lan-mouse cli activate 0     # ON: crossing works again
```

Heavier switches: stop the whole daemon with `systemctl --user stop lan-mouse` (hal9000) /
`launchctl bootout gui/$(id -u)/org.nix-community.home.lan-mouse` (halcyon), and start again with
`systemctl --user start lan-mouse` / `launchctl bootstrap gui/$(id -u)
~/Library/LaunchAgents/org.nix-community.home.lan-mouse.plist`. To disable permanently, set
`programs.lan-mouse.enable = false` in the module and redeploy.

Handy commands:

```bash
lan-mouse cli list                       # configured clients + state
systemctl --user status lan-mouse        # hal9000 (in its graphical session)
journalctl --user -u lan-mouse -f        # hal9000 logs (look for "emulation backend: wlroots")
launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.lan-mouse"   # restart on macOS
```

## Troubleshooting

- **Cursor won't cross at all** → macOS Accessibility not granted, or the agent wasn't restarted
  after granting.
- **Mouse crosses but keyboard/modifiers don't** → grant **Input Monitoring** too (macOS), then
  restart the agent. On hal9000 confirm `journalctl --user -u lan-mouse` shows
  `using emulation backend: wlroots` and that the running binary is **0.11.0** (`lan-mouse --version`)
  — 0.10.0 silently drops modifiers on Hyprland.
- **`failed to write config: Read-only file system`** in the journal → expected; the config is a
  Nix symlink. Manage `authorized_fingerprints` declaratively (above), not via `lan-mouse cli`.
- **`InputCapture portal ... not found` WARN on hal9000** → benign; it only affects capturing _on_
  hal9000 (send-back), which falls back to the `layer-shell` backend. Receiving is unaffected.
