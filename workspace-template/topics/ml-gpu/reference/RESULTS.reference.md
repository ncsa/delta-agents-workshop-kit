# Results: ml-gpu

JOBID: 22465994

## Evidence

Copied exactly from the log of that job (`grep -E '^\[ws-env\]|^[A-Z_]+: |^RESULTS_OK' slurm-<id>.out`):

- `[ws-env] host=gpub002.delta.ncsa.illinois.edu job=22465994 gpu=NVIDIA A40 module=pytorch-conda/2.12`
- THROUGHPUT: 127714.6
- ACCURACY: 0.8790
- `RESULTS_OK`
- plot: `ml-gpu.png`

## What changed

none: the oracle runs the prepared job.sbatch unchanged.

## How it was verified

sacct: 22465994|COMPLETED|0:0|00:00:26|gpub002|gpuA40x4-interactive||billing=1000,cpu=16,gres/gpu=1,mem=48G,node=1; numbers copied from slurm-22465994.out by grep; ws-check ml-gpu below.

## One limitation

One seed and one 2-epoch run on one A40; throughput varies by a few percent between runs.
