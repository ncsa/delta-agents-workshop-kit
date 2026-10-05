# M6 analyze

## Objective

Numbers are extracted, one plot exists, RESULTS.md is written, and
`ws-check <topic>` reports level 3: the prepared topic is done.

## Agent script

1. In one call (rule 19): `module reset && module load <module> && python
   topics/<topic>/analyze.py slurm-<jobid>.out` (or the results file the topic
   README names); `<module>` is `llmflux` for llm-batch, else
   `pytorch-conda/2.12`. Both have matplotlib: never `pip install` it. It
   prints the metric lines, writes `<topic>.png` and prints a `PLOT:` line
   (each curve's trend, min and max). Do not open the image (rule 20): to say
   what the plot shows, quote the `PLOT:` line.
2. Write RESULTS.md from `topics/<topic>/RESULTS.md.in`: `JOBID:`, the
   evidence lines copied from the log, what changed, how it was verified, one
   limitation.
3. Show `git diff RESULTS.md` (rule 24).
4. `ws-check <topic>` (`--tailored` for topic 5). Follow the hint until it
   reports level 3. Never edit a number to match; fix the cause.
5. `git add -A && git commit -m "M6"` (the harness asks), then the checkpoint
   and the next step: M7, open-ended.

## Participant does

Open the PNG in the Code Server file browser if you like (you look at images;
the agent does not) and compare it with the `PLOT:` line the agent quotes.

## What to expect

Each number in RESULTS.md appears in the log: `grep -n '<KEY>:'
slurm-<jobid>.out` shows it next to the job id. `ws-check <topic>` reports
`LEVEL: 3`. Throughput and elapsed time depend on the GPU; accuracy or error
should not move much on another one.

## Checkpoint

`ws-progress M6 "RESULTS.md; <EVIDENCE>=<value>; plot <file>; ws-check level 3"`,
then end the module with:

```
Result: <what happened, with the evidence>
Checkpoint: M6 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next step, a statement>; type `go` to continue.
```
