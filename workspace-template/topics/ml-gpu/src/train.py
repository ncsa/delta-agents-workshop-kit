#!/usr/bin/env python3
"""Train a small CNN on FashionMNIST on one GPU and report throughput and accuracy.

Adapted from the TOOL-083 ddp-baseline seed (train_ddp.py). Single process on one GPU
by default. If the usual torch.distributed variables are set (RANK, WORLD_SIZE,
MASTER_ADDR, MASTER_PORT, as torchrun sets them) it joins a process group and wraps
the model in DistributedDataParallel: that branch is dormant until the TAILOR.md
stretch (2-node DDP).

Data: the four FashionMNIST idx files (.gz or unpacked) are read from a local
directory, `--data <dir>` holding `raw/` (or the files themselves). Nothing is ever
downloaded; a compute node has no business fetching data. `--synthetic` uses
generated tensors with the same shapes instead, so the topic never blocks on data.

Log protocol (topics/LOG-PROTOCOL.md): prints `EPOCH n loss <l> acc <a>` per epoch,
then `THROUGHPUT: <samples/s>`, `ACCURACY: <test accuracy>`, `RESULTS_OK` last.

    python -u src/train.py --data data/FashionMNIST --epochs 2 --batch-size 256 --seed 1234
    python src/train.py --synthetic --epochs 1 --limit 512 --device cpu      # smoke test
"""
import argparse
import gzip
import os
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.distributed as dist
import torch.nn as nn
from torch.nn.parallel import DistributedDataParallel

FILES = {
    "train_images": "train-images-idx3-ubyte",
    "train_labels": "train-labels-idx1-ubyte",
    "test_images": "t10k-images-idx3-ubyte",
    "test_labels": "t10k-labels-idx1-ubyte",
}


class SmallCNN(nn.Module):
    """Two conv blocks and two linear layers: about 0.4 M parameters."""

    def __init__(self, classes=10):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 32, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),
        )
        self.head = nn.Sequential(
            nn.Flatten(), nn.Linear(64 * 7 * 7, 128), nn.ReLU(), nn.Linear(128, classes),
        )

    def forward(self, x):
        return self.head(self.features(x))


def is_distributed():
    return "RANK" in os.environ and "WORLD_SIZE" in os.environ


def log(msg):
    print(msg, flush=True)


def read_idx(path):
    """Read one idx file (plain or .gz) into a numpy array."""
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rb") as fh:
        data = fh.read()
    magic = int.from_bytes(data[0:4], "big")
    ndim = magic & 0xFF
    dims = [int.from_bytes(data[4 + 4 * i:8 + 4 * i], "big") for i in range(ndim)]
    return np.frombuffer(data, dtype=np.uint8, offset=4 + 4 * ndim).reshape(dims)


def find_file(root, stem):
    for d in (root / "raw", root, root / "FashionMNIST" / "raw"):
        for name in (stem, stem + ".gz"):
            if (d / name).is_file():
                return d / name
    return None


def load_fashionmnist(root):
    root = Path(root)
    paths = {k: find_file(root, v) for k, v in FILES.items()}
    missing = [FILES[k] for k, p in paths.items() if p is None]
    if missing:
        raise SystemExit(
            f"FashionMNIST files not found under {root} (missing: {', '.join(missing)}). "
            "This script never downloads. Check the data/ link in this topic, ask a helper, "
            "or rerun with --synthetic.")
    arrays = {k: read_idx(p) for k, p in paths.items()}

    def images(a):
        return torch.from_numpy(a.astype(np.float32) / 255.0).unsqueeze(1)

    def labels(a):
        return torch.from_numpy(a.astype(np.int64))

    return (images(arrays["train_images"]), labels(arrays["train_labels"]),
            images(arrays["test_images"]), labels(arrays["test_labels"]))


def synthetic(n_train, n_test, seed):
    """Learnable fake data: each class is a fixed random 28x28 pattern plus noise."""
    g = torch.Generator().manual_seed(seed)
    patterns = torch.rand(10, 1, 28, 28, generator=g)

    def make(n):
        y = torch.randint(0, 10, (n,), generator=g)
        x = (0.6 * patterns[y] + 0.4 * torch.rand(n, 1, 28, 28, generator=g)).clamp(0, 1)
        return x, y

    xtr, ytr = make(n_train)
    xte, yte = make(n_test)
    return xtr, ytr, xte, yte


def pick_device(name, local_rank):
    if name == "cpu":
        return torch.device("cpu")
    if not torch.cuda.is_available():
        if name == "cuda":
            raise SystemExit(
                "no CUDA device visible: this must run inside a GPU job "
                "(keep --gpus-per-node=1 in job.sbatch), or pass --device cpu for a smoke test")
        return torch.device("cpu")
    torch.cuda.set_device(local_rank)
    return torch.device("cuda", local_rank)


def sync(device):
    if device.type == "cuda":
        torch.cuda.synchronize(device)


def evaluate(model, x, y, batch_size, device):
    model.eval()
    correct = 0
    with torch.no_grad():
        for i in range(0, len(x), batch_size):
            xb, yb = x[i:i + batch_size], y[i:i + batch_size]
            correct += (model(xb).argmax(1) == yb).sum().item()
    model.train()
    return correct / max(1, len(x))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--data", default="data/FashionMNIST", help="directory holding raw/ with the idx files")
    ap.add_argument("--synthetic", action="store_true", help="use generated data instead of FashionMNIST")
    ap.add_argument("--epochs", type=int, default=2)
    ap.add_argument("--batch-size", type=int, default=256, help="per-rank batch size")
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--seed", type=int, default=1234)
    ap.add_argument("--limit", type=int, default=0, help="use only the first N train and test samples (0 = all)")
    ap.add_argument("--warmup", type=int, default=10, help="steps excluded from the throughput timing")
    ap.add_argument("--amp", action="store_true", help="bf16 autocast (TAILOR.md stretch a)")
    ap.add_argument("--device", choices=("cuda", "cpu", "auto"), default="cuda")
    ap.add_argument("--threads", type=int, default=0, help="torch CPU threads (0 = torch default)")
    args = ap.parse_args()

    if args.threads > 0:
        torch.set_num_threads(args.threads)

    if is_distributed():
        rank = int(os.environ["RANK"])
        world_size = int(os.environ["WORLD_SIZE"])
        local_rank = int(os.environ.get("LOCAL_RANK", 0))
        dist.init_process_group(backend="nccl" if args.device != "cpu" else "gloo")
    else:
        rank, world_size, local_rank = 0, 1, 0

    device = pick_device(args.device, local_rank)
    gpu = torch.cuda.get_device_name(device) if device.type == "cuda" else "none"
    log(f"[rank {rank}/{world_size}] host={os.uname().nodename} local_rank={local_rank} "
        f"device={device} gpu={gpu} torch={torch.__version__}")

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    if args.synthetic:
        n_train = args.limit or 60000
        n_test = args.limit or 10000
        xtr, ytr, xte, yte = synthetic(n_train, n_test, args.seed)
        source = "synthetic"
    else:
        xtr, ytr, xte, yte = load_fashionmnist(args.data)
        if args.limit:
            xtr, ytr, xte, yte = xtr[:args.limit], ytr[:args.limit], xte[:args.limit], yte[:args.limit]
        source = "FashionMNIST"
    if rank == 0:
        log(f"DATASET: {source} train={len(xtr)} test={len(xte)}")

    # Each rank trains on its own shard (the dormant DDP branch); one rank = the whole set.
    xtr, ytr = xtr[rank::world_size], ytr[rank::world_size]
    # The whole set is ~220 MB as float32: keep it on the device, so batches never wait on the host.
    xtr, ytr, xte, yte = (t.to(device) for t in (xtr, ytr, xte, yte))

    model = SmallCNN().to(device)
    if is_distributed():
        model = DistributedDataParallel(model, device_ids=[local_rank] if device.type == "cuda" else None)
    opt = torch.optim.Adam(model.parameters(), lr=args.lr)
    loss_fn = nn.CrossEntropyLoss()
    amp_dtype = torch.bfloat16 if args.amp else None

    gen = torch.Generator().manual_seed(args.seed)
    steps_per_epoch = -(-len(xtr) // args.batch_size)
    # Short smoke runs keep at least half of their steps timed.
    warmup = min(args.warmup, (steps_per_epoch * args.epochs) // 2)
    step = 0
    timed_samples = 0
    eval_seconds = 0.0  # evaluation between epochs is not training: excluded from THROUGHPUT
    start = None
    for epoch in range(1, args.epochs + 1):
        perm = torch.randperm(len(xtr), generator=gen)
        loss_sum, seen = torch.zeros((), device=device), 0
        for i in range(0, len(xtr), args.batch_size):
            if step == warmup:
                sync(device)
                if is_distributed():
                    dist.barrier()
                start = time.perf_counter()
            idx = perm[i:i + args.batch_size].to(device)
            xb, yb = xtr[idx], ytr[idx]
            opt.zero_grad(set_to_none=True)
            with torch.autocast(device_type=device.type, dtype=amp_dtype, enabled=args.amp):
                loss = loss_fn(model(xb), yb)
            loss.backward()
            opt.step()
            # detach() keeps the sum on the device: no host sync per step (.item() would add one)
            loss_sum += loss.detach().float() * len(idx)
            seen += len(idx)
            if start is not None:
                timed_samples += len(idx)
            step += 1
        sync(device)
        t_eval = time.perf_counter()
        acc = evaluate(model, xte, yte, 1024, device)
        sync(device)
        if start is not None:
            eval_seconds += time.perf_counter() - t_eval
        if rank == 0:
            log(f"EPOCH {epoch} loss {loss_sum.item() / max(1, seen):.4f} acc {acc:.4f}")

    sync(device)
    if start is None or timed_samples == 0:  # nothing timed: report no number rather than a fake one
        raise SystemExit(f"only {step} training steps, nothing was timed; raise --limit or --epochs")
    elapsed = time.perf_counter() - start - eval_seconds
    per_rank = timed_samples / elapsed
    total = torch.tensor([per_rank], device=device)
    if is_distributed():
        dist.all_reduce(total, op=dist.ReduceOp.SUM)

    if rank == 0:
        log(f"[rank 0] {timed_samples} timed samples in {elapsed:.2f}s across {world_size} rank(s)")
        log(f"THROUGHPUT: {total.item():.1f} samples/s")
        log(f"ACCURACY: {acc:.4f}")
        log("RESULTS_OK")

    if is_distributed():
        dist.barrier()
        dist.destroy_process_group()
    return 0


if __name__ == "__main__":
    sys.exit(main())
