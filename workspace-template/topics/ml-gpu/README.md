# Topic 1: `ml-gpu` — train a small CNN on one GPU

## Goal

Train a small convolutional network on FashionMNIST for 2 epochs on one A40,
report throughput and test accuracy, and prove it ran on the GPU.

## Background

1. PyTorch on Delta comes from the module `pytorch-conda/2.12` (torch 2.12.1,
   CUDA 13.0 build; torchvision, numpy and matplotlib included). No `conda activate`.
2. A GPU job is a CPU job plus `--gpus-per-node=1`; without it torch sees no CUDA.
3. `srun` launches the job step, so Slurm accounts for it and `sacct` shows it.

## Acceptance

`ws-check ml-gpu` reports level 3:

- the job COMPLETED on `gpuA40x4` in the workshop reservation when one is configured (`ws-check` skips that check otherwise), `gres/gpu=1`;
- its log has `[ws-env] ... gpu=NVIDIA A40`, `THROUGHPUT:` at least 20000
  samples/s, `ACCURACY:` at least 0.80, and ends with `RESULTS_OK`;
- RESULTS.md has `JOBID: <that job>` and the same two numbers (5 % for
  throughput, 1 % for accuracy);
- `ml-gpu.png` exists and is newer than the log.

## Choices

The decisions for your plan (M2). Each has its cost and says whether the level-3 check of
`check.sh` (the keys `THROUGHPUT:` and `ACCURACY:`, 20000 samples/s and 0.80) stays as it is.

1. **Epochs** (`--epochs` in `job.sbatch`, default 2). Anything from 1 to 5: each epoch
   adds seconds on the A40, far below the job's 10 minutes. The reference run reached
   0.855 after one epoch and 0.879 after two. Keeps level 3.
2. **Batch size** (`--batch-size`, default 256). From 128 to 1024: the throughput moves,
   and that is the experiment. A larger batch takes fewer steps per epoch, so accuracy
   after 2 epochs may drop (not measured; add an epoch if it falls near 0.80). Keeps
   level 3 while `ACCURACY:` stays at 0.80 or more.
3. **Mixed precision** (`--amp`, bf16 autocast). Two ways. In the main job: the log keeps
   the same keys, but the thresholds were calibrated without AMP (a small risk). Or keep
   the main job as it is and run AMP as a second job for an A/B comparison
   (`TAILOR.md` a): a stretch after level 3, one more job of the same length.

## Files

| File | What it is |
|---|---|
| `envcheck.sbatch` | 30-second job: `[ws-env]` line with `gpu=`, torch version, `cuda=True`. |
| `job.sbatch` | The training job: 1 A40, 16 cores, 48 GB, 10 minutes. |
| `src/train.py` | The model and training loop; prints `EPOCH n loss acc`, `THROUGHPUT:`, `ACCURACY:`, `RESULTS_OK`. |
| `analyze.py` | `python analyze.py slurm-<id>.out`: prints the metric lines and writes `ml-gpu.png`. |
| `RESULTS.md.in` | The template for RESULTS.md. |
| `TAILOR.md` | Stretch items: AMP A/B, 2-node DDP, the NCCL fallback lesson. |
| `data/` | A link to the pre-staged FashionMNIST files (read-only). |
| `reference/` | A real log from the dry run: "reference run, not yours". |

## Environment

```
module reset && module load pytorch-conda/2.12
```

Put that in the same command as the thing that needs it, and in the job
script (it is already in `job.sbatch`). Never pipe `module load`.

On the harness node you may check that it imports
(`module reset && module load pytorch-conda/2.12 && python -c "import torch; print(torch.__version__)"`);
it will say `cuda False` there. That is expected: the GPU is in the job.

## Pitfalls

- Removing `--gpus-per-node=1`: torch sees no CUDA and `train.py` stops with
  "no CUDA device visible".
- Downloading data: `train.py` never downloads. If `data/FashionMNIST` is
  missing, ask a helper or use `--synthetic` (and say so in RESULTS.md).
- Running `train.py` on the harness node "to test": the harness node has no GPU
  and is shared. Use `--synthetic --epochs 1 --limit 512 --device cpu` at most.
- Reporting a number from `reference/`: that is not your job; `ws-check` knows.
- More DataLoader-style workers than `--cpus-per-task`, or `--ntasks-per-node`
  above 1 (then `srun` starts the script twice).
- Throughput counts training steps only (evaluation is excluded, the first 10
  steps are warm-up); it varies by a few percent between runs.
