# Topic 2: `pinn` — a physics-informed neural network for the 1-D heat equation

## Goal

Train a small MLP to satisfy `u_t = α u_xx` on (0, 1) × (0, 0.5) with
`u(x, 0) = sin(πx)` and `u(0, t) = u(1, t) = 0` (α = 0.05), compare it with the
analytic solution `u = exp(-α π² t) sin(πx)`, and report the relative L2 error.

## Background

1. A PINN replaces data with physics: the loss is the PDE residual `u_t - α u_xx`,
   computed by autograd at sampled points, plus the initial and boundary conditions.
2. Collocation points are sampled at random inside the domain, not on a grid.
3. The analytic solution exists here only so you can measure the error honestly;
   the network never sees it. (Day 1, 15:00 "Scientific ML" goes further.)

## Acceptance

`ws-check pinn` reports level 3:

- the job COMPLETED on `gpuA40x4` in the workshop reservation when one is configured (`ws-check` skips that check otherwise), `gres/gpu=1`;
- its log has `[ws-env] ... gpu=NVIDIA A40`, `L2_ERROR:` at most 2e-2,
  `PDE_RESIDUAL:`, and ends with `RESULTS_OK`;
- RESULTS.md has `JOBID: <that job>` and the same `L2_ERROR:` and
  `PDE_RESIDUAL:` (within 5 % or 1e-3 absolute);
- `pinn.png` exists and is newer than the log.

## Choices

The decisions for your plan (M2). Each has its cost and says whether the level-3 check of
`check.sh` (the key `L2_ERROR:` at most 2e-2, and `PDE_RESIDUAL:`) stays as it is.

1. **Collocation points** (`--n-colloc` in `job.sbatch`, default 2000). One value from
   1000 to 10000 keeps the keys and level 3 (the reference: `L2_ERROR` 7.6e-4 at 2000,
   47 s of training). More points cost more time per step (not measured above 2000; the
   job's limit is 8 minutes). The three-value sweep of `TAILOR.md` a renames the keys
   (`L2_ERROR@200:`), which the checker does not read: a stretch after level 3.
2. **L-BFGS after Adam** (`--lbfgs 200`, default none). On an A40 it moved L2_ERROR by
   under 1% (C20 rehearsal) for about 2 s: a lesson about optimizers, not accuracy; each
   iteration costs several loss evaluations, so stay at 200 or fewer to fit 8 minutes.
   Keeps level 3.
3. **CPU versus GPU** (`TAILOR.md` b). A second job on the CPU partition with the same
   network. `ws-check pinn` scores the GPU job (`gres/gpu=1` on `gpuA40x4`), so the CPU
   job never counts and never lowers the level: a stretch after level 3, one more job.

## Files

| File | What it is |
|---|---|
| `envcheck.sbatch` | 30-second job: `[ws-env]` line with `gpu=`, torch version, `cuda=True`. |
| `job.sbatch` | The training job: 1 A40, 16 cores, 48 GB, 8 minutes. |
| `src/pinn.py` | MLP 4×32 tanh, Adam 8000 steps (`--lbfgs 200` adds L-BFGS), `--n-colloc 2000 --alpha 0.05`, fixed seed. Prints `STEP n loss`, `L2_ERROR:`, `PDE_RESIDUAL:`, `TRAIN_SECONDS:`, `RESULTS_OK`. |
| `analyze.py` | `python analyze.py slurm-<id>.out`: prints the metric lines and writes `pinn.png` (loss curve; predicted vs exact at t = 0.25 and 0.5). |
| `RESULTS.md.in` | The template for RESULTS.md. |
| `TAILOR.md` | Stretch items: collocation sweep, CPU-vs-GPU honesty check, your own linear PDE. |
| `reference/` | A real log from the dry run: "reference run, not yours". |

No data: the points are generated.

## Environment

```
module reset && module load pytorch-conda/2.12
```

Put it in the same command as the thing that needs it; it is already in
`job.sbatch`. Never pipe `module load`.

## Pitfalls

- Dropping `create_graph=True` from `torch.autograd.grad`: the second
  derivative silently vanishes and the "PDE" is not the heat equation.
- Sampling collocation points on the boundary (the script keeps them inside).
- Adding many L-BFGS iterations: each one costs several loss evaluations and
  can blow the 8-minute box. Try `--lbfgs 200` at most.
- Reporting the training loss as the error: `L2_ERROR:` compares with the exact
  solution; the loss does not.
- float32 has a residual noise floor near 1e-6: smaller numbers mean nothing.
- "Improving" the result by editing `check.sh`: `ws-check` runs the kit's
  read-only copy, not yours.
