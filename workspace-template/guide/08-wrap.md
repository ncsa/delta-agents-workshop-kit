# M8 wrap

## Objective

Consolidate what was learned in both parts, the prepared topic and the
open-ended project, and point the participant to `ON-YOUR-OWN.md` for their
own research project. Ask nothing. Start only after a typed "wrap up" (or
`/wrap`): record it first (`ws-progress --note "wrap up"`, which ends M7 for
`ws-status`).

## Agent script

1. Summary: PROGRESS.md in five lines: the prepared topic (PLAN.md's goal,
   what ran, where, the job id, the evidence, the `ws-check` level) and the
   open-ended project (the goal, the environment, the job id, the `KEY: value`
   it printed). Copy every number from PROGRESS.md or a job log; no metric
   the topic does not print. No `open/` job, or it has not ended: say so
   (rule 26). `open/` not committed: `git add open && git commit -m "M7"`
   (the harness asks).
2. Take-home: `ls open/`, read `ON-YOUR-OWN.md` and point to it; never edit
   it, AGENTS.md or `guide/` (kit files). Give two or three of its points,
   each tied to a file that exists (no `open/`: PLAN.md), for example:
   `open/AGENTS.md` is a starter for their own project folder (or `/init`
   there once code exists, never here): add their allocation's submit command
   and caps; keep a PLAN.md with an evidence line per milestone, like
   `open/PLAN.md`; a module plus a venv, like `open/.venv` (none made: the
   environment section of `ON-YOUR-OWN.md`). One line: the guide stays in the
   workspace, and the `ws-*` helpers are short bash scripts in the kit to copy
   and adapt.

## Participant does

Read the summary. Run `git log --oneline` and read your own history. Open
`ON-YOUR-OWN.md`; note the kit location from the quick card. Optional:
`/feedback` (hpc-gpt) mails a note, with this session attached, to the
hpc-gpt team at NCSA.

## What to expect

The three checks that make a result real, named in the summary: it ran where
you think (`sacct`); the work happened (the evidence line); the number is real
(it is in the log of that job id). Each take-home point names a file that
exists.

## Checkpoint

`ws-progress M8 "wrapped; <topic> level <n>; open-ended <goal> job <id>; ON-YOUR-OWN.md pointed to"`,
then end the module with:

```
Result: <what happened, with the evidence>
Checkpoint: M8 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <what they do after the workshop>
```
