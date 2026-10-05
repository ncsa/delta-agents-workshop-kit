# M3 env

## Objective

The topic's environment is proven on a compute node inside a job, not on the
node where the agent runs.

## Agent script

1. Read the Environment section of `topics/<topic>/README.md`.
2. Local check, labelled "harness node, no GPU": for example
   `module reset && module load pytorch-conda/2.12 && python -c "import torch; print(torch.__version__)"`,
   or `module reset && which cc && cc --version` for the C topic. One call,
   never piped.
3. Dry run: `ws-submit topics/<topic>/envcheck.sbatch` (`ws-submit --cpu`
   for a CPU topic: see its README), `sbatch` with the workshop's checks.
   Read the `sbatch` line it runs together.
4. PLAN.md needs its `approved:` line (rule 9; else back to M2 step 5). Then
   `ws-submit --yes topics/<topic>/envcheck.sbatch` (`--cpu` as in step 3;
   the harness asks; a 30-second job that prints
   `[ws-env] host= job= gpu= module=`).
5. `ws-wait <jobid> --timeout 100`, at most twice per reply (AGENTS.md §4),
   then `ws-log <jobid>`.
6. `sacct -P -j <jobid> -o JobID,State,Elapsed,NodeList,Partition,Reservation,AllocTRES`.

## Participant does

Approve the submission in the harness prompt. In the `sbatch` line
`ws-submit` runs, find the account (`$WS_ACCOUNT_GPU`), partition (`$WS_PART_GPU`), reservation
(`$WS_RES_GPU`, if any), time and GPU count (CPU topic: `$WS_ACCOUNT_CPU`,
`$WS_PART_CPU`, `$WS_RES_CPU`, 16 CPUs).

## What to expect

Before the submission, one line: "cuda True on an `NVIDIA A40`, elapsed under
60 s, a short queue in the reservation", because the job only imports torch
and multiplies one matrix. Then compare with the `[ws-env]` line and `sacct`,
and say how long the job queued. CPU topic: `gpu=none`, `cc` is the Cray
wrapper.

## Checkpoint

`ws-progress M3 "<module> ok; cuda True (CPU topic: cc=<path>) on <node> (job <id>)"`,
then end the module with:

```
Result: <what happened, with the evidence>
Checkpoint: M3 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```
