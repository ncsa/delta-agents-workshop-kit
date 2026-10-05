# M2 plan

## Objective

The participant chooses a prepared topic, reads its code and
checker, makes one or two choices and approves PLAN.md; nothing runs before
that (rule 9). Ask only the menu, the choices and the approval.

## Agent script

1. Choose: "Which fits you best today? (1) ML training on a GPU, (2)
   physics-informed neural network, (3) LLM batch inference with LLMFlux, (4)
   compile and parallelize C code (OpenMP/MPI, CPU), (5) tailor one of these
   to my field." The menu comes from `topics/README.md` alone (`question`
   tool if listed, one answer). Say that their own goal comes after level 3,
   in M7. No topic named: ask again; never choose for them. Unsure: one
   follow-up (field, Python or C?); recommend (1), no Python (4), LLMs (3),
   PDEs (2), their own field (5). `ws-progress --set topic <topic>` (for (5):
   the base topic; `ws-check` then takes `--tailored`).
2. Survey `topics/<topic>/` only, in one or two replies: the README (what it
   does), the source and `job.sbatch` in two lines, `check.sh`: the evidence
   lines and thresholds that mean "done".
3. Decide: one or two choices from the README's "Choices", numbered, each
   with its cost, whether level 3 stays, and your recommendation; then one
   typed question for their picks and their goal in one sentence (never
   "shall we").
4. Fill in PLAN.md: the goal in their words, each choice with its reason and
   cost, milestones whose evidence is `check.sh`'s lines, two to four project
   rules. `PLAN.example.md` is your reference for a sound plan, not a form.
   Show `git diff PLAN.md`.
5. Approve: they edit, or approve in words ("approved", "I approve"); "ok",
   "go on", "keep going", a steer or a new request is not an approval: show
   the approval line again and ask. Then add `approved: <NetID> <HH:MM>`
   (`ws-status` time), show it, and `git add PLAN.md && git commit -m "M2
   plan"` (the harness asks).

## Participant does

Choose, read the code, make and explain the choices, correct the draft,
approve it in your own words.

## What to expect

Every milestone names a command and an evidence line from `check.sh`
(`THROUGHPUT:` at least 20000, `RESULTS_OK`). Rewrite any that says "works"
or "looks good" before asking to approve.

## Checkpoint

`ws-progress M2 "topic <name> (tailored: say so); goal <PLAN.md's goal>; PLAN.md approved <HH:MM>; choices <a>, <b>"`,
then end the module with:

```
Result: <what happened, with the evidence>
Checkpoint: M2 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```
