# Plan

participant: <user> · date: <date> · topic: ml-gpu

The example plan: the agent's reference for a sound plan.

## Goal

Train the small CNN in `topics/ml-gpu/src/train.py` on FashionMNIST on one A40 and find out how
fast it trains and how accurate it gets, proven by `THROUGHPUT:` and `ACCURACY:` in the job log.

## Choices

1. Epochs: 2, as prepared. Why: enough for accuracy above 0.80, and the job stays short.
   Cost: seconds on the A40; no risk to level 3.
2. Batch size: 256, as prepared. Why: the calibrated setting. Cost: none.
3. Mixed precision: not in the main job; an A/B job with `--amp` only after level 3.
   Why: the thresholds were calibrated without it. Cost: one more job, only if time allows.

## Milestones

1. M3 environment: `ws-submit topics/ml-gpu/envcheck.sbatch`, then `--yes`.
   Evidence: the log shows `[ws-env] ... gpu=NVIDIA A40 ... cuda=True`.
2. M4-M5 job: `ws-submit topics/ml-gpu/job.sbatch`, then `--yes`.
   Evidence: `sacct` shows COMPLETED on gpuA40x4 in the reservation with `gres/gpu=1`; the log
   has `THROUGHPUT:` (at least 20000), `ACCURACY:` (at least 0.80) and `RESULTS_OK`.
3. M6 results: `python topics/ml-gpu/analyze.py slurm-<jobid>.out` writes `ml-gpu.png`;
   RESULTS.md cites the job id.
   Evidence: `ws-check ml-gpu` reports level 3.

## Rules for this project

- Load `pytorch-conda/2.12` inside the job: the harness node has no GPU.
- Report `THROUGHPUT` and `ACCURACY` only from our own job's log, never from `reference/`:
  `ws-check` compares RESULTS.md with that log.
- No data download: `train.py` reads the staged `data/FashionMNIST`.

## Approval

approved:
