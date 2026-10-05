# Plan

participant: <user> · date: <date> · topic: pinn

The example plan: the agent's reference for a sound plan.

## Goal

Train the PINN in `topics/pinn/src/pinn.py` for the 1-D heat equation on one A40 and find out how
close it gets to the exact solution, proven by `L2_ERROR:` in the job log.

## Choices

1. Collocation points: 2000, as prepared. Why: the calibrated setting (L2 error 7.6e-4 in the
   reference). Cost: about 47 s of training; no risk to level 3.
2. L-BFGS after Adam: none. Why: Adam alone passes the 2e-2 threshold, and the job stays short.
   Cost: none.
3. CPU versus GPU: a CPU job with the same network only after level 3. Why: it does not count
   for the checker. Cost: one more job, only if time allows.

## Milestones

1. M3 environment: `ws-submit topics/pinn/envcheck.sbatch`, then `--yes`.
   Evidence: the log shows `[ws-env] ... gpu=NVIDIA A40 ... cuda=True`.
2. M4-M5 job: `ws-submit topics/pinn/job.sbatch`, then `--yes`.
   Evidence: `sacct` shows COMPLETED on gpuA40x4 in the reservation with `gres/gpu=1`; the log
   has `L2_ERROR:` (at most 2e-2), `PDE_RESIDUAL:` and `RESULTS_OK`.
3. M6 results: `python topics/pinn/analyze.py slurm-<jobid>.out` writes `pinn.png`;
   RESULTS.md cites the job id.
   Evidence: `ws-check pinn` reports level 3.

## Rules for this project

- Load `pytorch-conda/2.12` inside the job: the harness node has no GPU.
- Report `L2_ERROR` only from the job log: the training loss is not the error.
- Keep `create_graph=True` in `residual()`: without it the second derivative vanishes silently.

## Approval

approved:
