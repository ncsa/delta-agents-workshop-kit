#!/usr/bin/env python3
"""Fetch the four FashionMNIST raw files once, for the workshop lead (not for participants).

Run on a login node (it needs the network; compute jobs never download):

    python3 stage_fashionmnist.py "$WS_KIT_RO/data/ml-gpu/FashionMNIST"

writes <dir>/raw/{train,t10k}-{images-idx3,labels-idx1}-ubyte.gz (~30 MB, MIT licence,
https://github.com/zalandoresearch/fashion-mnist), which is where `ws-init` links
topics/ml-gpu/data and where train.py looks (`--data data/FashionMNIST`).
Standard library only. Files already present and valid are kept. Each file is checked
by its idx header (magic number and sample count) and its MD5 is compared with the
value torchvision uses; a mismatch is reported.
"""
import argparse
import gzip
import hashlib
import os
import sys
import urllib.request
from pathlib import Path

MIRRORS = (
    "http://fashion-mnist.s3-website.eu-central-1.amazonaws.com/",
    "https://raw.githubusercontent.com/zalandoresearch/fashion-mnist/master/data/fashion/",
)
# name: (md5 as in torchvision.datasets.FashionMNIST, idx magic, number of items)
FILES = {
    "train-images-idx3-ubyte.gz": ("8d4fb7e6c68d591d4c3dfef9ec88bf0d", 2051, 60000),
    "train-labels-idx1-ubyte.gz": ("25c81989df183df01b3e8a0aad5dffbe", 2049, 60000),
    "t10k-images-idx3-ubyte.gz": ("bef4ecab320f06d8554ea6380940ec79", 2051, 10000),
    "t10k-labels-idx1-ubyte.gz": ("bb300cfdad3c16e7a12a480ee83cd310", 2049, 10000),
}


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def header_ok(path, magic, count):
    try:
        with gzip.open(path, "rb") as fh:
            head = fh.read(8)
    except (OSError, EOFError):
        return False
    return (len(head) == 8 and int.from_bytes(head[0:4], "big") == magic
            and int.from_bytes(head[4:8], "big") == count)


def fetch(name, dest, timeout):
    last = None
    for base in MIRRORS:
        tmp = dest.with_name(dest.name + ".part")
        try:
            with urllib.request.urlopen(base + name, timeout=timeout) as r, open(tmp, "wb") as out:
                while block := r.read(1 << 20):
                    out.write(block)
            os.replace(tmp, dest)
            return base
        except OSError as e:
            last = e
            tmp.unlink(missing_ok=True)
            print(f"  {base}{name}: {e}", file=sys.stderr)
    raise SystemExit(f"could not fetch {name} from any mirror (last error: {last})")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("dir", help="target directory; the files go into <dir>/raw/")
    ap.add_argument("--timeout", type=float, default=60.0, help="seconds per request")
    args = ap.parse_args()

    raw = Path(args.dir) / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    bad = 0
    for name, (want_md5, magic, count) in FILES.items():
        dest = raw / name
        if dest.is_file() and header_ok(dest, magic, count):
            source = "kept"
        else:
            source = fetch(name, dest, args.timeout)
        if not header_ok(dest, magic, count):
            print(f"FAIL {dest}: not an idx file with magic {magic} and {count} items", file=sys.stderr)
            bad += 1
            continue
        got = md5(dest)
        note = "md5 ok" if got == want_md5 else f"md5 {got} differs from the torchvision value {want_md5}"
        os.chmod(dest, 0o644)
        print(f"OK   {dest} ({dest.stat().st_size} bytes, {count} items, {note}; {source})")
    if bad:
        return 1
    print(f"STAGED: {raw}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
