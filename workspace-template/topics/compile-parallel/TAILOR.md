# compile-parallel: stretch and tailor

Only after M6 is done (level 3). Every item keeps the caps (16 cores or 1 GPU,
15 minutes) and goes through `ws-submit`. With `ws-check compile-parallel --tailored`
the speedup thresholds relax to "the metric is in the log and matches RESULTS.md";
the scheduler checks and the 1e-9 agreement of the `RESULT:` values stay.

## a. CUDA on one A40 (two jobs)

`src/pi_cuda.cu` computes the same integral on the GPU: each thread sums a
grid-stride share, each block reduces in shared memory, one `atomicAdd` per block.

1. Compiling needs no GPU, so it happens in the CPU job, never on the
   session node (no `nvcc` there, not even as a check): add one line to
   `job.sbatch` after the `make -B` line:
   `make cuda NVCC="$(which nvcc)"` (nvcc 13.2, `-arch=sm_86` for the A40).
   Check first that the CPU job sees `nvcc`: the `envcheck.sbatch` log has a `NVCC:` line.
2. `ws-submit --cpu job.sbatch`, then `--yes`; it builds `build/pi_cuda` as well.
3. Read `job.cuda.sbatch` together (1 A40, `srun build/pi_cuda "$N"`), then
   `ws-submit job.cuda.sbatch` (a GPU job: no `--cpu`), and `--yes`.
4. Compare its `RESULT:` with the CPU runs (atomic additions come in any order,
   so the last digits may change between runs; it must still agree within 1e-9)
   and its `TIME:` with `pi_omp` on 16 threads. Say what the GPU time excludes
   (the context start-up, which the warm-up launch absorbs) and put both job ids
   and numbers under "What changed" in RESULTS.md.

## b. A memory-bound kernel: measure, do not assert

π is compute-bound: every step is a division, nothing comes from memory. A 1-D
stencil is the opposite: `b[i] = (a[i-1] + a[i] + a[i+1]) / 3` over arrays much
larger than the caches does three loads and one store for three flops.

1. Write `src/stencil_omp.c` from `pi_omp.c`: two `double` arrays of 2^27
   elements (1 GiB each; within `--mem=16g`), initialise them in a parallel loop
   (first touch places the pages near the threads), time 10 sweeps, print
   `RESULT: <checksum> TIME: <s> WORKERS: <t>` and the bandwidth as
   `BANDWIDTH_GBS: <bytes moved / time / 1e9>`.
2. Add it to the `Makefile` and to `job.sbatch` with 1/2/4/8/16 threads.
3. Before looking: state the 16-thread speedup you expect and why, and write it down.
4. Compare the measured speedup with π's. If it flattens, check the bandwidth
   line against what one socket can deliver; if it does not flatten, say so.
   The claim in RESULTS.md is what the log shows, not what the textbook says.

## Tailor to your field

- Your own small C, C++ or Fortran code (it must build in under 2 minutes with
  `cc`, `CC` or `ftn`, inside the job): adapt the `Makefile`, keep the evidence lines
  (`[ws-env]`, a `RESULT:`-style line per run, a speedup line, `RESULTS_OK`).
- Then check with `ws-check compile-parallel --tailored`.
