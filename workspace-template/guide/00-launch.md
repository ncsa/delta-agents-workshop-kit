# M0 launch

## Objective

The agent runs on a compute node (in the workshop CPU reservation when
`ws-status` shows one; a login node also works), the workspace exists, and
PROGRESS.md is started.

## Agent script

1. Run `ws-status`. Read the node line: compute node or login node.
2. On `dt-login` (rule 13): say once that the node is shared, that all work
   goes into jobs, and that the `srun` line `ws-status` prints is
   recommended for the session; then carry on.
3. Read the PROGRESS.md header: participant, node, harness.
4. Say in two sentences how we work: "I work through each milestone with you
   and explain each step as I go; the harness asks you before I submit a job,
   edit a file or change permissions. You can type your own request at any
   time, or "slow down" for one step per reply. At the end of each milestone
   I stop; type anything, such as "go", to continue."
5. Name the three layers in one short paragraph: the house rules (AGENTS.md:
   fixed, they protect a shared machine and 50 people), the session guide
   (`guide/`), and your plan (PLAN.md, which we write together in M2). The
   session has two parts: a prepared topic to level 3, then an
   open-ended part on a goal of your own (M7).
6. Record the checkpoint and continue into M1.

## Participant does

The participant already did this to reach you; repeat it only if they
relaunch.

- Code Server: Open OnDemand, Interactive Apps, Code Server. Account
  `$WS_ACCOUNT_CPU`, partition `$WS_PART_CPU`, reservation `$WS_RES_CPU`
  (empty: nothing to type; jobs on the workshop account find the reserved
  nodes on their own), 2 CPUs, 4G RAM, 0 GPUs, duration `1:45:00` (the quick
  card's values; a relaunch uses them again). Connect, open a terminal.
- ssh instead: log in to a login node; `ws-init` prints the `srun` line for
  a compute-node shell (its `--time` fits the reservation; recommended), or
  stay on the login node.
- Then: `source <kit>/env.sh && ws-init`, then `cd ~/ws-2026-10-05` and start
  an agent: `hpc-gpt` (or `opencode`; `claude`/`codex`/`gemini` if you have
  one), then type `start`.

## What to expect

`hostname` starts with `cn`: a CPU compute node, where this session runs as a
Slurm job. Say so, run it, show the line. Then say in one sentence which
module we are on (from `ws-status`; quote none of it).

## Checkpoint

`ws-progress M0 "on <node> via Code Server|srun; harness <name>"`, then end the
module with:

```
Result: <what happened, with the evidence>
Checkpoint: M0 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```
