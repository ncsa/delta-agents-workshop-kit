# Log protocol, job caps and acceptance levels

Every topic follows the same three conventions, so `ws-log`, `ws-check` and
each topic's `analyze.py` can read any job the same way.

## Log protocol

Every job prints, in this order, to its Slurm output file:

1. One environment line:
   `[ws-env] host=<hostname> job=<SLURM_JOB_ID> gpu=<GPU name|none> module=<module>`
2. The topic's evidence lines, one `KEY: value` per line, for example
   `THROUGHPUT: 9120.4`, `L2_ERROR: 4.1e-03`, `SPEEDUP_OMP16: 11.2`,
   `ANSWERED: 40`.
3. `RESULTS_OK` as the last line, only on success.

`analyze.py` and `check.sh` parse only these lines. Scripts flush stdout
(`python -u`, `print(..., flush=True)` or `stdbuf -oL`) so the lines appear
while the job runs. The `llm-batch` topic is the one exception: LLMFlux owns
its log, so its checker reads the results file instead of `RESULTS_OK`.

## Job caps

- `#SBATCH` lines never carry account, partition or reservation: `ws-submit`
  adds `$WS_ACCOUNT_GPU` or `$WS_ACCOUNT_CPU`, `$WS_PART_GPU` or
  `$WS_PART_CPU`, and `$WS_RES_GPU` or `$WS_RES_CPU`.
- GPU topics: `--nodes=1 --gpus-per-node=1 --cpus-per-task=16 --mem=48g`,
  `--time` at most `00:15:00`.
- CPU topic: submit with `ws-submit --cpu`, which uses `$WS_PART_CPU`.
- Output stays in the workspace: `--output=slurm-%j.out`.

## Acceptance levels (`ws-check <topic>`)

| Level | Meaning |
|---|---|
| 0 | No job can be attributed to this workspace (by `sacct` WorkDir or `.ws/jobs.tsv`). |
| 1 | A job ran, in any end state. |
| 2 | A job COMPLETED on the allowed partition with the workshop reservation and the right `AllocTRES` (for example `gres/gpu=1`), and its log has the `[ws-env]` line, the topic's evidence lines inside their thresholds, and `RESULTS_OK`. |
| 3 | Level 2, and RESULTS.md has `JOBID: <that job>`, every reported number matches the log (within 5 %, or 1e-3 absolute for errors), and the plot file exists and is newer than the log. |

`ws-check` prints `LEVEL: n`, the checks, the evidence, and one `hint:` line
naming what is missing for the next level. It runs the kit's read-only copy
of `check.sh`, so editing the workspace copy changes nothing.
