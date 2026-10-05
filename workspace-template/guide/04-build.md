# M4 build

## Objective

The topic's code and job script are ready, understood and syntax-checked.

## Agent script

1. Walk through `topics/<topic>/src/` in at most three chunks: what it
   computes, where it prints the evidence lines (`topics/LOG-PROTOCOL.md`),
   what the seed does.
2. Walk through `topics/<topic>/job.sbatch` (llm-batch: `run.sh`): why
   `module reset`, why `srun`, why `--cpus-per-task`, why the output stays in
   the workspace, why there is no account, partition or reservation
   (`ws-submit` adds them).
3. Make the change PLAN.md's Choices name (epochs, collocation points,
   threads, prompts...) as one edit (the harness asks); none if the plan keeps
   the prepared script. A new idea: check it against the plan first (rule 5).
4. Show `git diff` (rule 24).
5. Syntax checks: `bash -n topics/<topic>/job.sbatch` (llm-batch: `bash -n
   topics/llm-batch/run.sh`); Python: `python -m py_compile
   topics/<topic>/src/*.py`. C code: no compiler on this node, not even a
   syntax check (rule 13): the job compiles it, and its log shows any error.
6. Dry run: `ws-submit topics/<topic>/job.sbatch` (`--cpu` for a CPU topic;
   llm-batch: `bash topics/llm-batch/run.sh`), `sbatch` with the workshop's
   checks. Quote the line it prints and point at it: "this is the `sbatch`
   command it runs: account, partition, time, GPU" (llm-batch: the `llmflux`
   command; LLMFlux runs `sbatch` itself). Do not add `--yes` yet; that is M5.

## Participant does

Approve the planned edit in the harness prompt, or type another request.
Read the diff.

## What to expect

One line on how the change moves the evidence number and why (for example
"3 epochs instead of 2: accuracy up a little, elapsed about 1.5 times"). Write
it with `ws-progress --note` so M5 can compare. No change: the reference numbers.

## Checkpoint

`ws-progress M4 "job.sbatch ready; change: <what>"`, then end the module with:

```
Result: <what happened, with the evidence>
Checkpoint: M4 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```
