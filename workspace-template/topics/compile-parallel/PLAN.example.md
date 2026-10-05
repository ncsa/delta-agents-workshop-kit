# Plan

participant: <user> · date: <date> · topic: compile-parallel

The example plan: the agent's reference for a sound plan.

## Goal

Build the serial, OpenMP and MPI π integrators in `topics/compile-parallel/src/` with the Cray
`cc` wrapper, run them in one 16-core CPU job, and find out how much faster 16 workers are,
proven by agreeing `RESULT:` lines and `SPEEDUP_OMP16:` and `SPEEDUP_MPI16:` in the job log.

## Choices

1. Emphasis: OpenMP (the code walk and the analysis); MPI stays in the job. Why: the checker
   needs both speedups. Cost: none.
2. Thread counts and pinning: 1, 2, 4, 8, 16 with `OMP_PROC_BIND=close`, as prepared. Why: the
   calibrated curve. Cost: none.
3. Problem size: `N=1e9`, as prepared. Why: long enough to time, short enough to rerun.
   Cost: about 2 s for the serial run.

## Milestones

1. M3 environment: `ws-submit --cpu topics/compile-parallel/envcheck.sbatch`, then `--yes`.
   Evidence: the log shows `[ws-env] ... cc=/opt/cray/pe/craype/.../bin/cc` and `RESULTS_OK`.
2. M4-M5 job: `ws-submit --cpu topics/compile-parallel/job.sbatch`, then `--yes`.
   Evidence: `sacct` shows COMPLETED on `cpu` in the reservation with `cpu=16`; the log has
   seven `RESULT:` lines that agree within 1e-9, `SPEEDUP_OMP16:` (at least 6),
   `SPEEDUP_MPI16:` (at least 6), `RESULT_AGREE: yes` and `RESULTS_OK`.
3. M6 results: `analyze.py` on that log prints the speedup table and writes `scaling.png`;
   RESULTS.md cites the job id.
   Evidence: `ws-check compile-parallel` reports level 3.

## Rules for this project

- Compile and time inside the job only: the harness node is shared (`make -n` is fine there).
- Launch MPI with `srun`, never `mpirun`: `mpirun` is not supported on Delta.
- Correctness before speed: no speedup is reported while the `RESULT:` values disagree.

## Approval

approved:
