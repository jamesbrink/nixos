#!/usr/bin/env python3
"""Archive a revision and every pinned gitlink, without dirty checkout files."""

import argparse
from pathlib import Path
import subprocess


def stage(repo, revision, destination):
    destination.mkdir(parents=True, exist_ok=True)
    archive = subprocess.Popen(
        ["git", "-C", str(repo), "archive", revision], stdout=subprocess.PIPE
    )
    try:
        subprocess.run(["tar", "-x", "-C", str(destination)], stdin=archive.stdout, check=True)
    finally:
        archive.stdout.close()
    if archive.wait() != 0:
        raise RuntimeError(f"Cannot archive {repo} at {revision}")
    entries = subprocess.check_output(
        ["git", "-C", str(repo), "ls-tree", "-rz", revision]
    ).split(b"\0")
    for entry in entries:
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, pinned = metadata.decode().split()
        if mode != "160000":
            continue
        child = Path(name.decode())
        subprocess.run(
            ["git", "-C", str(repo / child), "cat-file", "-e", pinned + "^{commit}"],
            check=True,
        )
        stage(repo / child, pinned, destination / child)
        print(f"Included pinned submodule {child}: {pinned}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("revision")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    repo = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
    destination = args.destination.absolute()
    if destination.exists():
        raise SystemExit("Destination must not exist; refusing to overwrite existing staging")
    if destination == repo or repo in destination.parents:
        raise SystemExit("Destination must be outside the repository")
    stage(repo, args.revision, destination)
    print(f"Staged committed revision {args.revision} at {destination}")


if __name__ == "__main__":
    main()
