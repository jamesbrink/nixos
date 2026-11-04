# GitHub Actions runners for the `rust` CI job of quantierra/nyc-real-estate-rust
# (that repo's .github/workflows/ci.yml and docs/ci.md): `runs-on: qre-rust`.
#
# Two long-lived runners, so two pull requests build at once. Everything that
# lasts (sccache, CARGO_HOME, two build dirs keyed by the manifests, the trees
# that passed) lives on the storage-fast/qre-ci ZFS dataset at CACHE_DIR; the
# job only uses it when it is a mount point, and runs uncached otherwise.
#
# Registration reads TOKEN_FILE (root 0600, provisioned by hand like the
# other hand-placed files on this host; see docs/qre-ci-runners.md): a
# fine-grained PAT for the quantierra org with "Self-hosted runners:
# read/write" keeps re-registering on its own; a one-hour registration token
# (`gh api -X POST /orgs/quantierra/actions/runners/registration-token`)
# registers once, and the unit's state dir keeps the credentials until the
# file, the labels or the URL change.
#
# Isolation follows quantierra/infra's loader-dev runners: a plain system
# user, no tailnet (the dev database lives there), no Docker, memory capped
# so one runaway link cannot take the box down, no tailnet DNS beyond
# MagicDNS itself.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  runners = [
    "qre-rust-1"
    "qre-rust-2"
  ];
  cacheDir = "/var/cache/github-runner/qre-rust";
  tokenFile = "/etc/github-runner/quantierra.token";
in
{
  users.groups.github-runner = { };
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
    home = "/var/lib/github-runner-home";
    createHome = true;
    description = "GitHub Actions runner (quantierra)";
  };

  # Work dirs on disk, not in the unit's tmpfs RuntimeDirectory: a checkout
  # per job. The cache dataset is created by hand (`zfs create -o
  # mountpoint=${cacheDir} storage-fast/qre-ci`) and mounted by
  # zfs-mount.service; its root is chowned once, on the dataset.
  systemd.tmpfiles.rules = [
    "d /var/cache/github-runner 0755 root root -"
    "d /var/lib/github-runner-work 0750 github-runner github-runner -"
    "d /etc/github-runner 0700 root root -"
  ]
  ++ map (n: "d /var/lib/github-runner-work/${n} 0750 github-runner github-runner -") runners;

  services.github-runners = lib.genAttrs runners (n: {
    enable = true;
    url = "https://github.com/quantierra";
    inherit tokenFile;
    name = "hal9000-${n}";
    extraLabels = [ "qre-rust" ];
    # Long-lived: the registration survives restarts with a registration
    # token; a PAT would allow `ephemeral = true` (a fresh runner per job).
    ephemeral = false;
    replace = true;
    user = "github-runner";
    group = "github-runner";
    workDir = "/var/lib/github-runner-work/${n}";
    # The job runs inside `nix develop`, which brings its own toolchain;
    # these are for actions/checkout and the job script's plumbing.
    extraPackages = with pkgs; [
      config.nix.package
      bash
      coreutils
      findutils
      gnugrep
      gnused
      gawk
      git
      gh
      python3
      jq
      curl
      gnutar
      gzip
      zstd
      xz
      unzip
      openssh
      util-linux
      rsync
    ];
    serviceOverrides = {
      # The persistent cache, outside the work dir.
      ReadWritePaths = [ cacheDir ];
      # As on loader-dev, where this job is proven: the real uid for the nix
      # daemon socket and the cache dataset's ownership.
      PrivateUsers = false;
      # A full workspace build at 32 jobs peaks well under this; the cap is
      # for a runaway, not the normal case. Two runners may both build.
      MemoryHigh = "28G";
      MemoryMax = "36G";
      # Jobs can leave processes behind; always come back, quickly.
      Restart = lib.mkForce "always";
      RestartSec = 5;
      TimeoutStopSec = 15;
      LimitCORE = 0;
      # No tailnet: the dev database and the other hosts live there. The box
      # resolves through systemd-resolved, which may forward to MagicDNS.
      IPAddressAllow = [
        "100.100.100.100"
        "fd7a:115c:a1e0::53"
      ];
      IPAddressDeny = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
    };
  });

  # Start after the cache dataset is mounted: the job keys everything on it
  # being a mount point, and a runner that came up before zfs-mount would
  # run its first job uncached.
  systemd.services = lib.listToAttrs (
    map (
      n:
      lib.nameValuePair "github-runner-${n}" {
        after = [
          "zfs-mount.service"
          "network-online.target"
        ];
        wants = [
          "zfs-mount.service"
          "network-online.target"
        ];
      }
    ) runners
  );
}
