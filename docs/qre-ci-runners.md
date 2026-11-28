# qre-rust CI runners on hal9000

`modules/services/qre-ci-runners.nix` runs two GitHub Actions runners,
`hal9000-qre-rust-1` and `-2`, registered to the `quantierra` org with the
label `qre-rust`. They take the `rust` job of
`quantierra/nyc-real-estate-rust`'s `.github/workflows/ci.yml` (clippy, the
test suite against a throwaway Postgres in `/dev/shm`, the `.sqlx/` check,
machete, deny), which ran on loader-dev's shared 4-core lanes before
(18-50 min a run) and runs on hal9000's 32 cores now. That repo's `docs/ci.md`
describes the job; this page is the host side.

## Hand-provisioned pieces

Two things are not in Nix, on purpose:

- **The cache dataset**, `storage-fast/qre-ci`, mounted at
  `/var/cache/github-runner/qre-rust` and owned by `github-runner`. The job
  keeps sccache, `CARGO_HOME`, two build dirs keyed by the manifests, and the
  trees that passed there, and only uses the directory when it is a mount
  point (an unmounted cache means "run uncached", never "write under it").

  ```sh
  sudo zfs create -o mountpoint=/var/cache/github-runner/qre-rust -o compression=lz4 storage-fast/qre-ci
  sudo chown github-runner:github-runner /var/cache/github-runner/qre-rust
  ```

- **The registration token**, `/etc/github-runner/quantierra.token` (root
  0600). Either of:
  - a fine-grained PAT for the `quantierra` org with _Self-hosted runners:
    read and write_: the units register themselves whenever their
    configuration changes, and `ephemeral = true` becomes possible;
  - a one-hour registration token, enough for `ephemeral = false` runners,
    which keep their credentials in the unit's state dir until the token
    file, the URL or the labels change:

    ```sh
    gh api -X POST /orgs/quantierra/actions/runners/registration-token --jq .token \
      | sudo install -m 0600 -o root -g root /dev/stdin /etc/github-runner/quantierra.token
    ```

  Replace the file and `systemctl restart github-runner-qre-rust-{1,2}` to
  re-register (for a new label, say).

## Checks

```sh
systemctl status github-runner-qre-rust-1 github-runner-qre-rust-2
gh api orgs/quantierra/actions/runners --jq '.runners[] | select(.name | startswith("hal9000")) | "\(.name) \(.status) busy=\(.busy)"'
sudo zfs list storage-fast/qre-ci
```

The first job on a fresh dataset builds the workspace from scratch (measured:
6 min 44 s for the whole job at 32 jobs); the ones after it compile only what
changed.

## Isolation

The units mirror quantierra/infra's loader-dev runners: a plain system user,
the nixpkgs module's hardening, no Docker, memory capped at 36G each, and
`IPAddressDeny` on the tailnet so a CI job can never reach loader-dev's
database or the other hosts.

## Factory overflow workers

`hosts/hal9000/factory-runner.nix` runs two separate rootless Podman workers,
`hal9000-1` and `hal9000-2`. These are Factory Rust overflow lanes, not
GitHub Actions runners. Each has a six-CPU, 14 GiB memory cap with no
container swap. The dedicated `factory-runner` user stores credentials in
separate Podman volumes and shares a build cache between the lanes.

Before the first start, copy the matching x86-64 Rust runner image from ECR
into the service user's Podman store as `localhost/factory-runner:current`.
The units never pull images or need AWS credentials. Provision each
single-use registration token as `FACTORY_REGISTRATION_TOKEN=…` in
`/etc/factory-runner/factory-runner-hal9000-{1,2}.env` (one file per lane,
root-owned, mode `0600`). Start `factory-runner-hal9000-{1,2}.service`,
verify both registrations on the Factory hub, then remove the token files.
Keep the Podman state volumes for subsequent starts.

The shared card cache (a cargo target per card, often 10-30 GB each) lives on
the `storage-ssd/factory-runner` ZFS dataset at `/mnt/storage-ssd/factory-runner`
(lz4, 500 GB quota), not on the root disk; the Podman store (the ~11 GB image and
container layers) stays in `/var/lib/factory-runner`. The dataset is created by
hand like the rest of that pool (commands in `hosts/hal9000/factory-runner.nix`).
Because storage-ssd is a USB disk imported by `storage-ssd-import.service`, the
workers bind to that unit: they start when it imports the pool, stop before
`systemctl stop storage-ssd-import` exports it, and refuse to start
(`AssertPathIsMountPoint`) when the dataset is not mounted.

The runner never evicts card caches itself yet, so
`factory-runner-cache-prune.timer` runs daily at 04:30: it removes card dirs
idle over 48 h, then the least recently used ones idle over 6 h while the
dataset is above 350 GB, never one a running process works in. It also removes
`remote-test.sh` targets under `/storage-fast/qre-remote/target` idle over
48 h (never `main`, only under the target's own lock). Run it by hand with
`systemctl start factory-runner-cache-prune`; the journal lists what it removed.

Before changing worker storage, drain both lanes on the Factory hub
(`factory workers drain hal9000-1`, same for `-2`); a drained lane exits 7 and
stays stopped. Start the units again and `factory workers enable` each lane.
