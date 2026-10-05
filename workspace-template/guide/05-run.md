# M5 run

## Objective

A real job runs through `ws-submit`, is watched to the end, and its log and
scheduler record are read.

## Agent script

1. State what you expect (M4's note), then `ws-submit --yes
   topics/<topic>/job.sbatch`, `sbatch` with the workshop's checks (`--cpu`
   for a CPU topic; llm-batch: `bash topics/llm-batch/run.sh --yes`; the
   harness asks). `ws-submit` records the job id in PROGRESS.md.
2. `squeue -u $USER` (or `/jobs` in opencode); explain the PENDING reason if
   any (`Priority`, `Resources`, `ReqNodeNotAvail`).
3. `ws-wait <jobid> --timeout 100`, at most twice per reply (AGENTS.md §4),
   then `ws-log <jobid>`. Outside a reservation (none, or it is full), a job
   on a busy partition can queue 5-10 minutes or more: the queue, not the
   runtime, is the schedule risk. Say so once.
4. `sacct -P -j <jobid> -o JobID,State,ExitCode,Elapsed,NodeList,Partition,Reservation,AllocTRES`
   and `seff <jobid>`.
5. `ws-check <topic>`; read the level and the hint.

## Participant does

Watch the state change. Find the evidence line in the log yourself.

## What to expect

Before the submission: state, elapsed time and the evidence value you expect,
and why (for example "COMPLETED in about a minute on one A40, THROUGHPUT above
20,000 samples/s"). When the job has ended, compare and name any surprise.

Exit 0 is not success. Show each check with its command: it ran on a GPU (the
`gpu=` field; CPU topic: `gpu=none`, `cpu=16` on `$WS_PART_CPU`), the number
comes from this job id, the partition is `$WS_PART_GPU` in `sacct`, and the
reservation is the one `ws-status` shows, if any (magnetic: or none, when
full).

If the job ends FAILED or TIMEOUT: quote the key error line from `ws-log`,
propose one fix with its reason, and resubmit after approval. After a second
failure, offer the prepared script unchanged.

## Checkpoint

`ws-progress M5 "job <id> COMPLETED <elapsed> on <node>; <EVIDENCE>=<value>; ws-check level <n>"`.
The module's end, in three lines:

```
Result: <what happened, with the evidence>
Checkpoint: M5 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```

For example "Result: job 22600035 COMPLETED in 27 s, THROUGHPUT 127924.5
(above 20,000)."
