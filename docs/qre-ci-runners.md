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
