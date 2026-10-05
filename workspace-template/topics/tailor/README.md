# Topic 5: `tailor` — adapt a base topic to your field

Pick one base topic (1-4) and one variant listed in its `TAILOR.md`, or a
small change of your own of the same size. You keep the base topic's job
shape, caps and evidence lines; only the science changes.

## Rules

- The caps stay: 1 GPU per node (or 16 CPU cores with `ws-submit --cpu`),
  one node, at most 15 minutes, submitted through `ws-submit`.
- No downloads in the job and no shared installs: data and models come from
  the kit (`data/`, `$WS_KIT_RO/models`) or from files you already have on Delta.
- The job keeps the base topic's log protocol: the `[ws-env]` line, the
  base topic's evidence lines (`KEY: value`, the same keys), and `RESULTS_OK`
  (for `llm-batch`: the results file in the same shape).
- Write PLAN.md first, with the variant and one measurable acceptance per milestone.

## The plan (M2)

The same shape as for every topic (`PLAN.md.in`), with the base topic as the existing
code: survey the base topic's README, source, `job.sbatch` and `check.sh`, then decide.

- **Goal**: your field's question in your words, and the base topic's metric that
  answers it.
- **Choices**: the variant (from the base's `TAILOR.md`) is the first choice; at most
  one more from the base README's "Choices". Say for each that the check is
  `ws-check <base> --tailored`, so the thresholds relax but the keys stay.
- **Milestones**: the base topic's evidence lines, with `--tailored` in M6.
- **Rules for this project**: what the variant must not change (the keys, the caps, no
  downloads), each with its reason.
- **Approval**: as for every topic; `ws-submit --yes` waits for it.

## Checking

```
ws-progress --set topic <base>   # record the base topic (M2)
ws-check <base> --tailored
```

`--tailored` relaxes the numeric thresholds (for example `THROUGHPUT ≥ 20000`)
to "the metric is in the log and matches RESULTS.md". Everything else stays:
COMPLETED on the workshop partition, in the reservation, with the right
`AllocTRES`; the `[ws-env]` and `RESULTS_OK` lines; RESULTS.md citing the job
id with numbers that match the log; the plot newer than the log. Correctness
checks of the base topic stay as well (the 1e-9 agreement of the
`compile-parallel` results).

| Base | Variants (see its `TAILOR.md`) |
|---|---|
| `ml-gpu` | your own small dataset or model from local files; `torch.profiler` top-5 kernels |
| `pinn` | your own 1-D/2-D linear PDE with a known solution; Burgers with the staged reference |
| `llm-batch` | your own 20-60 prompts and success rule; 1.5B vs 7B; raw vLLM |
| `compile-parallel` | your own C/C++/Fortran code that builds in under 2 minutes; a stencil |

In RESULTS.md, say under "What changed" which base and which variant, and why
the relaxed thresholds are fair for it.
