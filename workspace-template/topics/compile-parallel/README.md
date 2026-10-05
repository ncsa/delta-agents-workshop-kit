# Topic 4: `compile-parallel` — compile and parallelize a C code (OpenMP, MPI)

## Goal

Compile a serial midpoint-rule π integrator with the Cray compiler wrapper,
run it parallelized with OpenMP and with MPI in one 16-core CPU job, check
that all three give the same answer, and report the speedup with a scaling plot.

## Background

1. On Delta `cc`/`CC`/`ftn` are Cray PE wrappers around GCC 14 that add
   cray-mpich automatically: there is no `mpicc` to call and no flags to find.
2. `srun` is the MPI launcher (Slurm's default is PMIx); `mpirun` is not supported.
3. Correctness first, then speed: three `RESULT:` values that disagree make any
   speedup meaningless.

## Acceptance

`ws-check compile-parallel` reports level 3:

- the job COMPLETED on the `cpu` partition in the workshop CPU reservation when one is
  configured (`ws-check` skips that check otherwise),
  with `cpu=16` in `AllocTRES`;
- its log has the `[ws-env]` line, `RESULT:` values that agree within 1e-9,
  `SPEEDUP_OMP16:` at least 6, `SPEEDUP_MPI16:` at least 6,
  `RESULT_AGREE: yes`, and ends with `RESULTS_OK`;
- RESULTS.md has `JOBID: <that job>` and the same two speedups (within 5 %);
- `scaling.png` exists and is newer than the log.

## Choices

The decisions for your plan (M2). Each has its cost and says whether the level-3 check of
`check.sh` (`SPEEDUP_OMP16:` and `SPEEDUP_MPI16:` at least 6, every `RESULT:` within 1e-9,
`cpu=16`) stays as it is.

1. **OpenMP or MPI emphasis**: which program you read, change and explain in M4 and M6.
   Both stay in `job.sbatch`: the checker needs both speedups and all the `RESULT:` lines.
   Dropping one is a tailored plan (`ws-check compile-parallel --tailored`), or a stretch
   after level 3.
2. **Thread counts and pinning** (the `for t in 1 2 4 8 16` loop and `OMP_PROC_BIND`).
   Add counts such as 3, 6 or 12: each run takes 1-2 s at the default size. Keep 16
   (the checker reads `SPEEDUP_OMP16:`) and the 16-core job. Pinning `spread` instead of
   `close` is a fair experiment; without pinning the 16-thread speedup can fall
   toward the threshold of 6 (a risk; that run's log is not shipped). Keeps level 3.
3. **Problem size** (`N`, default 1e9 intervals, serial 1.75 s in the reference). Up to
   4e9 keeps level 3 and multiplies every run's time by the same factor. Below 1e9 the
   runs get short enough for timing noise to show in the speedup (a risk).

## Files

| File | What it is |
|---|---|
| `src/pi_serial.c`, `src/pi_omp.c`, `src/pi_mpi.c` | The three programs; each prints `PROGRAM:` and `RESULT: <pi> TIME: <s> WORKERS: <n>`. |
| `Makefile` | `make` builds all three into `build/` with `$(CC)` = `$(shell which cc)`. |
| `envcheck.sbatch` | 20-second job: `[ws-env]` with `cc=`, the compiler version, cray-mpich. |
| `job.sbatch` | The job: compile, serial, OpenMP 1/2/4/8/16 threads, MPI 16 ranks, then `src/report.py`. |
| `src/report.py` | Prints `SPEEDUP_OMP16:`, `SPEEDUP_MPI16:`, `RESULT_AGREE: yes`, `RESULTS_OK` (system `python3`). |
| `analyze.py` | `python analyze.py slurm-<id>.out`: prints the metrics and a speedup table, writes `scaling.png`. |
| `RESULTS.md.in` | The template for RESULTS.md. |
| `TAILOR.md` | Stretch items: CUDA on one A40, a memory-bound stencil; your own code. |
| `reference/` | A real log from the dry run: "reference run, not yours". |

## Environment

The default modules: `module reset` restores PrgEnv-gnu, cray-mpich and GCC 14.
Compilation happens **inside the job** (`job.sbatch` runs `make -B`). Submit with
the CPU flag:

```
ws-submit --cpu topics/compile-parallel/job.sbatch   # dry run; then --yes after approval
```

On the harness node, `make -n` (show the commands) is fine; building and timing
belong in the job. Run no compiler there, not even as a syntax check
(`cc -fsyntax-only`, `nvcc -c`): it is compute outside a job. `bash -n
job.sbatch` checks the script, and the job's log shows any compile error. The
plot needs matplotlib, which system `python3` lacks:

```
module reset && module load pytorch-conda/2.12 && python analyze.py slurm-<id>.out
```

## Pitfalls

- Bare `cc` resolving to `/usr/bin/cc` in a tool shell without the Cray paths:
  use `$(which cc)` after `module reset`, or the absolute path the Makefile falls back to.
- `mpirun`: use `srun --ntasks=16 --cpus-per-task=1`.
- `--cpus-per-task` is not inherited by `srun` steps (Slurm 22.05 and later):
  pass it on every `srun`, as `job.sbatch` does.
- `srun: Job step's --cpus-per-task value exceeds that of job (16 > 1). Job step
  may never run.` is expected: the job holds 16 CPUs as 16 one-CPU tasks, and
  the OpenMP steps ask for them as one task. The steps run; leave it.
- `OMP_NUM_THREADS` unset, or `srun` without `--cpus-per-task=$t`: all threads
  share one core and there is "no speedup".
- Threads without pinning: the job's 16 cores sit on several NUMA domains and
  unpinned threads can share or move between cores. `job.sbatch` exports
  `OMP_PROC_BIND=close OMP_PLACES=cores`; the shipped reference (pinned,
  `reference/slurm-reference.out`) shows 11.73; without pinning it can fall toward 6.
- `TIME:` is measured inside each program (the loop, and for MPI the reduction),
  so the `srun` start-up is not in it; `N=1e9` keeps the loop long enough to time.
- `-O3 -ffast-math` reorders the sum and changes `RESULT:` in the last digits;
  the tolerance is 1e-9, so a real bug (a missing `reduction`) still shows.
- Reporting a number from `reference/`: that is not your job; `ws-check` knows.
