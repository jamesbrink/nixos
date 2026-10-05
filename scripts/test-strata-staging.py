#!/usr/bin/env python3
"""Regression: staged revisions retain gitlinks but exclude unrelated dirty files."""

from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).with_name("stage-nixos-revision.py").resolve()


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def init(repo):
    repo.mkdir()
    git(repo, "init", "-q")
    git(repo, "config", "user.email", "fixture@example.invalid")
    git(repo, "config", "user.name", "Staging fixture")


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    child, parent = root / "encrypted-inputs", root / "parent"
    init(child)
    (child / "fixture.age").write_text("encrypted fixture only\n")
    git(child, "add", ".")
    git(child, "commit", "-qm", "test: encrypted fixture")
    init(parent)
    (parent / "flake.lock").write_text("committed lock\n")
    git(parent, "add", ".")
    git(parent, "commit", "-qm", "test: parent fixture")
    git(parent, "-c", "protocol.file.allow=always", "submodule", "add", "-q", str(child), "secrets")
    git(parent, "commit", "-qam", "test: pin fixture submodule")
    revision = git(parent, "rev-parse", "HEAD")
    (parent / "flake.lock").write_text("unrelated dirty lock\n")
    (parent / "untracked").write_text("not part of revision\n")
    destination = root / "staged"
    subprocess.run(["python3", str(script), revision, str(destination)], cwd=parent, check=True)
    assert (destination / "flake.lock").read_text() == "committed lock\n"
    assert not (destination / "untracked").exists()
    assert (destination / "secrets/fixture.age").read_bytes() == (child / "fixture.age").read_bytes()
    second = subprocess.run(["python3", str(script), revision, str(destination)], cwd=parent, capture_output=True)
    assert second.returncode != 0
    assert b"Destination must not exist" in second.stderr
print("Pinned encrypted gitlink retained; dirty/untracked files excluded; existing staging protected")
