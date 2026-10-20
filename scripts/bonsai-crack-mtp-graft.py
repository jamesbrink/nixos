#!/usr/bin/env python3
"""Graft the ProCreations Bonsai 2 MTP head onto dealignai's CRACK weights.

The ProCreations bundle is PrismML's official PQ2_0 file byte for byte plus one
NextN layer (blk.64). CRACK is the same official file with a subset of tensors
abliterated; names, types, shapes and metadata otherwise match. Copying the
bundle and overwriting each differing tensor's bytes in place with CRACK's
therefore yields CRACK + the same MTP head the original Bonsai entry serves.

Requires PrismML's gguf-py on PYTHONPATH (stock gguf-py lacks PQ2_0):
  python3 bonsai-crack-mtp-graft.py CRACK.gguf BUNDLE.gguf OUT.gguf
"""

import hashlib
import os
import shutil
import sys

import gguf


def tensors(reader: gguf.GGUFReader) -> dict[str, gguf.ReaderTensor]:
    return {t.name: t for t in reader.tensors}


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1 << 24):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    crack_path, bundle_path, out_path = sys.argv[1:4]
    crack, bundle = gguf.GGUFReader(crack_path), gguf.GGUFReader(bundle_path)
    ct, bt = tensors(crack), tensors(bundle)
    if not set(ct) <= set(bt):
        raise SystemExit(f"CRACK tensors missing from bundle: {sorted(set(ct) - set(bt))[:5]}")
    extra = sorted(set(bt) - set(ct))
    if not extra or not all(n.startswith("blk.64.") for n in extra):
        raise SystemExit(f"unexpected bundle-only tensors: {extra[:5]}")
    for name, t in ct.items():
        b = bt[name]
        if t.tensor_type != b.tensor_type or list(t.shape) != list(b.shape) or t.n_bytes != b.n_bytes:
            raise SystemExit(f"layout mismatch for {name}")
    changed = [n for n, t in ct.items() if t.data.tobytes() != bt[n].data.tobytes()]
    print(f"{len(ct)} shared tensors, {len(changed)} differ, {len(extra)} MTP tensors kept")

    tmp = out_path + ".partial"
    shutil.copyfile(bundle_path, tmp)
    with open(tmp, "r+b") as f:
        for name in changed:
            f.seek(bt[name].data_offset)
            f.write(ct[name].data.tobytes())

    out = tensors(gguf.GGUFReader(tmp))
    for name, t in ct.items():
        if out[name].data.tobytes() != t.data.tobytes():
            raise SystemExit(f"verification failed: {name} does not match CRACK")
    for name in extra:
        if out[name].data.tobytes() != bt[name].data.tobytes():
            raise SystemExit(f"verification failed: {name} does not match the MTP bundle")
    os.replace(tmp, out_path)
    print(f"verified; sha256 {sha256(out_path)}  {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
