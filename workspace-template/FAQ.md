# Questions to ask the agent, with short answers

Ask the agent anything, at any time: why something happened, whether you can do something,
how a piece works. It answers in a few lines, from this file, the Delta docs or a command it
runs for you, then goes back to the step it was on. The answers below are its starting point.

## How do I see this plot on my own computer?

- In Code Server, click the file in the Explorer: a `.png` or an `.svg` opens as a picture (an `.svg` shown as text has "Reopen as Preview" in the title bar).
- Right-click the file in the Explorer, then "Download…": it saves the file to your computer.
- From a terminal on your own computer (not on Delta; it asks for your password and Duo): `scp <netid>@login.delta.ncsa.illinois.edu:ws-2026-10-05/open/plot.svg .`
- You run that `scp` line yourself: the agent never opens images, and `scp` is not one of its commands.

## Why does my job wait?

`squeue -u $USER` gives the reason in the `NODELIST(REASON)` column; `squeue --start -j <id>` estimates the start.
`Priority`: jobs with a higher priority go first. `Resources`: it waits for free nodes or GPUs.
`ReqNodeNotAvail`: a node it needs is busy, reserved or down. `QOSGrpBillingMinutes`: the account's balance does not cover it.
`MaxGRESPerAccount`: you or the project already use the cores or GPUs the partition allows.

## What is a module?

A module loads a piece of installed software into your shell (Delta's module system is Lmod):
`module avail pytorch-conda` lists the versions, `module load pytorch-conda/2.12` loads one. A job
script starts with `module reset` and loads its own modules, so it runs the same whatever your
shell had loaded.

## What can the agent do, and what not?

`PERMISSIONS.md` lists what runs freely, what asks you first, what never runs, and which files
decide it. In short: it looks freely, asks before any change, and submits jobs only through
`ws-submit`, which is `sbatch` with the workshop's checks.

## Where do my files live?

Your workspace, `~/ws-2026-10-05`, is in your home directory (`/u/<netid>`), which is yours
alone. The kit and its data sit on `/work/hdd`, the project's large file system, where heavy job
input and output belongs. `quota` shows your limits and what you use.

## What did my job run, and what did it cost?

`sacct -j <id> -o JobID,State,ExitCode,Elapsed,NodeList,AllocTRES` shows the state, the time, the
node and what the job reserved; `seff <id>` shows its CPU and memory use once it has ended.
`.ws/jobs.tsv` keeps the `sbatch` line `ws-submit` printed for each job. Delta charges for what a
job reserves, not what it uses, and each partition has a charge factor (`gpuA40x4`: 0.5).

## How do I stop the agent?

Press **Esc** to interrupt a reply. At a permission prompt, Reject stops that one command. To stop
a job, ask the agent: it runs `ws-cancel --yes <id>`, which cancels only this workspace's jobs,
and the harness asks you first.

## What is a block headed "Compaction"?

The agent condensed the conversation to fit the model's context window (its working memory).
Your files, `PLAN.md` and `PROGRESS.md` are unchanged; carry on.

## Can the agent be wrong?

Yes. Ask it to show the evidence: the command it ran and the output line behind the claim. When
you think it is wrong, say so: it checks the point with you, with a command (AGENTS.md rule 27).

## Can I use my own data or code today?

Yes, in M7, inside the limits in `topics/open-ended/README.md`: everything in `open/`, 1 GPU or
16 cores and 15 minutes per job, 10 jobs. No sensitive or regulated data (the quick card): what
you type and what the agent reads go to the shared models.

## Which model is answering, and how do I switch?

`/models` in opencode lists the workshop's models and switches to another one; `ws-models` shows
which Lumen models answer with your key. Section 4 of the quick card says when to switch.

## What do I do after the workshop?

Read `ON-YOUR-OWN.md` in your workspace: how to set up an agent for your own project from an
empty directory, with a starter AGENTS.md, starter permissions, and plain `sbatch` without the
workshop's helpers.
