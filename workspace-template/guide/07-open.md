# M7 open

## Objective

After level 3, the participant's own goal in `open/`; it lasts until a typed
"wrap up". Say once, at the start: the budget is 10 jobs, and typing "wrap
up" ends this part.

## Agent script

1. Scaffold `open/` as its own small project, explaining each piece in one
   line as you write it: what they would do in an empty directory
   (`ON-YOUR-OWN.md`). Goal first (ask): from `topics/open-ended/IDEAS.md`
   (the slide; read `topics/open-ended/README.md` first) or their own. Then
   `open/README.md` (goal, how to run it); `open/AGENTS.md` (only its own
   rules: module, venv, job script, evidence line; the workspace AGENTS.md
   still applies); `open/PLAN.md` (step 2); `open/.venv` (step 3).
2. Mini-plan: three to five lines in `open/PLAN.md`: the goal, the
   environment, how we know it worked (a `KEY: value` line and its bar), 1
   GPU or 16 cores and 15 minutes per job. Only a message that approves in
   words ("approved", "I approve") approves it; "ok", "go on", "keep going",
   a steer or a new request does not: show the approval line again and ask.
   Then its `approved:` line.
3. Environment, on the session node, never in a job: `module reset && module
   load <module> && python -m venv --system-site-packages open/.venv`, then
   `open/.venv/bin/pip install <small extras>`; frameworks never from pip.
   Prove it in a job. C or LLMFlux: no venv (README).
4. Solve: code in `open/`; `cp topics/open-ended/job.template.sbatch
   open/job.sbatch`, then edit (never retype or write one from scratch). One
   question per job, `--cpu` unless it needs the GPU, 10 jobs at most
   (`ws-submit` refuses more; budget and steering: the README). Per
   iteration, one job per reply: edit, `git add -N open && git diff open/`, a
   dry run if the script changed, `--yes` (`sbatch` with the workshop's
   checks), `ws-wait`, `ws-log`, the result against the bar; then stop. A
   diagnostic is a job too.
5. Evidence: the log's `[ws-env]`, `KEY: value` and `RESULTS_OK` lines;
   `open/RESULTS.md` quotes them with the job id; `ws-check open-ended`
   reads it. `git add open && git commit -m "M7"`.

## Participant does

Pick the goal, approve the mini-plan, steer by typing.

## What to expect

Before each job: what it should print, and why. After a result, the
next iteration as a statement, not a yes/no question: "Next: I run X; type a
steer." Never propose the wrap and never count jobs aloud.

## Checkpoint

First result: `ws-progress M7 "open: <goal>; env <module>; job <id> <KEY>=<value>"`;
later ones: `ws-progress --note`. End each with:

```
Result: <what happened, with the evidence>
Checkpoint: M7 at <HH:MM>
Questions: <two they might ask about what this module showed>
Next: <next iteration, a statement>; type a steer.
```
