# Results: compile-parallel

JOBID: 22511559

## Evidence

Copied exactly from the log of that job (`grep -E '^\[ws-env\]|^[A-Z_0-9]+: |^RESULTS_OK' slurm-<id>.out`):

- `[ws-env] host=cn061.delta.ncsa.illinois.edu job=22511559 gpu=none module=PrgEnv-gnu cc=/opt/cray/pe/craype/2.7.36/bin/cc`
- SPEEDUP_OMP16: 11.73
- SPEEDUP_MPI16: 11.78
- RESULT_AGREE: yes
- `RESULTS_OK`
- plot: `scaling.png`

## What changed

none: the oracle runs the prepared job.sbatch unchanged (N=1e9).

## How it was verified

sacct: 22511559|COMPLETED|0:0|00:00:15|cn061|cpu||billing=16000,cpu=16,mem=16G,node=1; numbers copied from slurm-22511559.out by grep; ws-check compile-parallel below.

## One limitation

One run per thread count on one node; the timings include srun step start-up and vary between nodes.
