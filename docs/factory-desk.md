# Desk mode on hal9000

hal9000 is James's desktop. It also works for Quantierra: two factory workers
(`factory-runner-hal9000-{1,2}`, `hosts/hal9000/factory-runner.nix`), two GitHub
Actions runners (`github-runner-qre-rust-{1,2}`, [qre-ci-runners.md](qre-ci-runners.md))
and the remote Rust builds that arrive over ssh and run the Rust repo's
`scripts/remote-host.sh`. **Desk mode** stops all of it with one switch and
brings it all back after. `hosts/hal9000/factory-desk.nix` + `factory-desk.sh`.

## The switches

- **On the machine** (works with no network and no factory):

  ```sh
  sudo factory-desk on            # until "factory-desk off"
  sudo factory-desk on --for 4h   # ends by itself (90m, 1h30m, 2d)
  sudo factory-desk on --now      # also stops a CI job that is running (it is re-run elsewhere)
  sudo factory-desk off
  factory-desk status             # effective state, who set it, every unit
  ```

  The board refuses requests from a worker's own machine, so at the desk this
  is the way.

- **From the factory** (board: account menu → _Using my desktop_, the strip
  under the header, Settings → Workers → the host's card; CLI:
  `factory workers host desk hal9000 on|off [--for 4h] [--drain] [--now]`).
  omp-factory `docs/workers.md` "Desk mode" has the factory side.

## What it does

`factory-desk-sync.service` runs a pass every 15 s. The effective desk is the
local flag (`/var/lib/factory-desk/local`) OR a desk the factory set for this
host, read from the worker hub (`GET https://workers.factory.myquantierra.com:8443/workers/v1/desk`)
with one of the two runners' own credentials (read as root from their podman
state volumes at call time; never copied, logged or put in argv). A hub that
does not answer: its last answer counts for 10 minutes, then none; the local
flag always wins.

Desk **on**:

| What            | How                                                                                                                                                                                                                                                                                                                                                       |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| factory workers | local desk: both units stop at once; SIGTERM makes each runner give its job back with its commits and uncommitted work, and the host told the hub first (desk on, `why: local`), so the factory counts no loss and starts the job on another worker. Factory desk: the factory hands the jobs off itself; a unit stops once the hub shows its worker idle |
| GitHub runners  | an idle runner stops at once; a busy one drops to CPUWeight=1, IOWeight=1 and nice 19 and stops when its job ends (`factory-desk-gh-drain@<unit>`); `--now` / ci "now" stops it at once (the job fails with "runner has received a shutdown signal" and the factory re-runs it once elsewhere)                                                            |
| remote builds   | `~jamesbrink/.config/qre-remote.env` (only if absent or ours: its first line is the factory-desk marker) sets `QRE_REMOTE_SLOT_WAIT=0`, and `factory-desk-hold.service` holds the three build slots: a new remote build exits 75 ("no build slot free … retry later", never a test failure); a running one keeps its slot and finishes                    |

While the desk holds a unit, a marker in `/run/factory-desk/stopped/` (and the
local flag) keeps `Restart=`, a deploy or a boot from starting it again.

Desk **off**: the hold stops, our `qre-remote.env` goes, priorities go back,
and every unit the desk stopped starts again (the workers only when the
storage-ssd cache is mounted, as their own unit requires).

**Shutdown**: `factory-desk-shutdown.service` is ordered after the factory worker units, so it stops before them; when the system is really going down it tells
the hub "desk on, why shutdown" so the runners' stops count as planned. The
next boot's sync lifts it.

## Checking and undoing by hand

```sh
factory-desk status
journalctl -u factory-desk-sync -n 50
cat /run/factory-desk/state.json
```

Without the script (all of it, then all of it back):

```sh
sudo systemctl stop factory-runner-hal9000-1 factory-runner-hal9000-2 github-runner-qre-rust-1 github-runner-qre-rust-2
sudo systemctl start factory-runner-hal9000-1 factory-runner-hal9000-2 github-runner-qre-rust-1 github-runner-qre-rust-2
```

If `factory-desk` itself misbehaves: `sudo systemctl stop factory-desk-sync`,
`sudo rm -rf /var/lib/factory-desk/local /run/factory-desk`, remove
`~jamesbrink/.config/qre-remote.env` if its first line is the factory-desk
marker, `sudo systemctl stop factory-desk-hold`, then start the units above.
