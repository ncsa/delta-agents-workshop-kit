# Results: pinn

JOBID: 22466011

## Evidence

Copied exactly from the log of that job (`grep -E '^\[ws-env\]|^[A-Z_]+: |^RESULTS_OK' slurm-<id>.out`):

- `[ws-env] host=gpub002.delta.ncsa.illinois.edu job=22466011 gpu=NVIDIA A40 module=pytorch-conda/2.12`
- L2_ERROR: 7.5549e-04
- PDE_RESIDUAL: 3.6775e-03
- TRAIN_SECONDS: 46.66
- `RESULTS_OK`
- plot: `pinn.png`

## What changed

none: the oracle runs the prepared job.sbatch unchanged.

## How it was verified

sacct: 22466011|COMPLETED|0:0|00:00:58|gpub002|gpuA40x4-interactive||billing=1000,cpu=16,gres/gpu=1,mem=48G,node=1; numbers copied from slurm-22466011.out by grep; ws-check pinn below.

## One limitation

One seed, on a problem with a known exact solution; a real PINN problem has none to compare with.
