# pinn: stretch and tailor

Only after M6 is done (level 3). Every item keeps the caps: 1 GPU, 15 minutes,
submitted through `ws-submit`. With `ws-check pinn --tailored` the `L2_ERROR`
threshold relaxes to "the metric is in the log and matches RESULTS.md"; the
scheduler checks stay. `ws-check` scores your best job, so a stretch job that
does not fit the acceptance (a CPU job, a sweep) never lowers your level.

## a. Collocation sweep (one job, three steps)

How does the error depend on the number of collocation points?

1. Copy `job.sbatch` to `job.sweep.sbatch`; replace the `srun python` line with
   ```bash
   for n in 200 2000 20000; do
       srun python -u src/pinn.py --steps 8000 --n-colloc "$n" --alpha 0.05 --seed 1234 \
           | sed -E "s/^(L2_ERROR|PDE_RESIDUAL|TRAIN_SECONDS): /\1@$n: /; /^RESULTS_OK$/d"
   done
   echo RESULTS_OK
   ```
   so the log has `L2_ERROR@200:`, `L2_ERROR@2000:`, `L2_ERROR@20000:` lines.
   Raise `--time` to `00:15:00` (three runs).
2. State the expected order of magnitude of the three errors, and why, before submitting (rule 23).
3. Plot error against points (log-log) with a few lines of matplotlib, from the
   log lines; report the three numbers and the job id.

## b. CPU versus GPU: an honesty check

A 4×32 network with 2000 points is tiny. Does it need a GPU?

1. Copy `job.sbatch` to `job.cpu.sbatch`: remove `--gpus-per-node=1`, use
   `--cpus-per-task=16 --mem=16g`, and add `--device cpu --threads 16` to the
   `srun python` line.
2. Submit it with `ws-submit --cpu job.cpu.sbatch` (the CPU partition).
3. Compare `TRAIN_SECONDS:` and `L2_ERROR:` with the GPU job. Say plainly which
   was faster and why (kernel launch overhead versus arithmetic). The GPU is not
   always the right tool; measuring is how you find out.

## c. Your own linear PDE

A 1-D or 2-D linear PDE with a known exact solution (for example `u_t = α u_xx
+ f(x, t)` with a manufactured solution, or the 1-D wave equation).

1. Write down the residual; change `residual()` and `exact()` in `src/pinn.py`
   (the agent helps derive the derivatives; keep `create_graph=True`).
2. Keep to ≤ 8000 steps and the evidence lines `L2_ERROR:`, `PDE_RESIDUAL:`,
   `TRAIN_SECONDS:`, `RESULTS_OK`.
3. Check with `ws-check pinn --tailored` (your problem may not reach 2e-2).
