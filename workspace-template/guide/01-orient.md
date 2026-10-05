# M1 orient

## Objective

A short look: where we are on Delta (login nodes edit and submit,
compute nodes run the work, this session is a Slurm job on one), then
the workspace. Inform: say what each command shows, then the line. Two
replies: steps 1-5, then 6-8. End the first with the next step and what to
type: "Next: modules and permissions. Type `go` to
continue, or ask about anything above, e.g. <a question on this reply>."

## Agent script

1. Where we are: `hostname; echo "job=$SLURM_JOB_ID partition=$SLURM_JOB_PARTITION"; nproc`.
2. The workspace, under a minute: AGENTS.md, house rules every harness reads;
   `guide/`, the session script by module; `ws-*` helpers and the read-only
   kit; PLAN.md and PROGRESS.md, plan and memory; permissions: step 7. End:
   "This is special to a workshop; `ON-YOUR-OWN.md` shows your own setup."
3. Account: `accounts`; name only the two on `ws-status`'s `accounts:` line.
4. Files: `quota`; the workspace in `$HOME` (private, small), data on
   `/work/hdd` (large, shared).
5. Reservation (`ws-status`). `(magnetic)`: the workshop's; jobs
   enter it on their own, or the general queue when full. "not configured":
   none.
6. Modules: `module avail pytorch-conda llmflux`, then in one call
   `module reset && module load pytorch-conda/2.12 && which python`: topic
   jobs load 2.12, not the default 2.8.
7. Permissions (`PERMISSIONS.md`), four lines at most: an example each:
   runs freely, asks first, never runs; the files that decide
   (`opencode.json`, `.claude/settings.json`). Then create `scratch.txt` with
   the file-edit tool (no redirect, not in `/tmp`) so the prompt appears; its
   answers: Allow once, Allow always (until restart), Reject. Never
   allow-all: it catches a wrong command. Last: the page stays; they write
   their own map (`ON-YOUR-OWN.md`).
8. If time allows: `sinfo -s -p cpu,$WS_PART_GPU`; the `$WS_PART_GPU` charge
   factor, quoted from the docs tool with its URL (rule 25).

## Participant does

Approve the scratch file; ask anything.

## What to expect

`hostname` starts with `cn`, `job=` shows a number (empty on `dt-login`);
`nproc` prints 2, the job's CPUs, not the node's. Name any difference.

## Checkpoint

`ws-progress M1 "account <account>; quota ok; res <name> <state> (or none); permissions tour"`;
then one line: questions are welcome any time, part of working with an
agent. End with the four lines below; the questions are about what M1 just
showed (for example "why does `nproc` print 2?", "what happens when the
reservation is full?", "what would Allow always do?"):

```
Result: <what happened, with the evidence>
Checkpoint: M1 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```
