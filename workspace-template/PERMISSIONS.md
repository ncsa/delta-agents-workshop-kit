# What the agent may run here, and what decides it

The agent works through a harness: opencode (what `hpc-gpt` starts) or Claude Code. The
harness, not the model, decides for every command whether it runs, asks you first, or never
runs. It checks each command against a permission map in this workspace before anything
happens, so a wrong command from the model stops at the map or at your prompt.

## Runs without asking: read-only looks

These change nothing, so the agent runs them as often as a step needs:

| Command | Why it runs freely |
|---|---|
| `ls` | lists the files in a folder (opencode only) |
| `cat PLAN.md` | shows a file (opencode only; Claude Code reads files with its Read tool) |
| `squeue -u $USER` | shows your jobs in the queue |
| `git diff` | shows what changed in your files |
| `ws-submit topics/ml-gpu/job.sbatch` | a dry run: prints the `sbatch` command and submits nothing |

## Asks you first: changes

These change your files, your environment or the machine's queue, so the harness shows you
the exact command and waits for your answer:

| Command | Why it asks |
|---|---|
| A file edit, for example creating `scratch.txt` | it changes a file: read the diff the agent shows |
| `ws-submit --yes topics/ml-gpu/job.sbatch` | it submits a job on the workshop's account |
| `open/.venv/bin/pip install seaborn` | it installs a package into your workspace |
| `python open/plot.py` | it runs code, which can do anything the code says |
| `git commit -m "M7"` | it records a version in your history |

## Never runs: cannot be undone, shows a secret, or goes around the caps

The harness refuses these without a prompt, whatever the model tries:

| Command | Why it never runs |
|---|---|
| `rm -rf open` | it deletes a folder and everything in it, with no way back |
| `printenv` | it prints every variable, tokens included |
| `cat ~/.ssh/id_ed25519` | it shows a private key |
| `sbatch job.sbatch` | the agent submits only through `ws-submit` (below) |
| `scancel -u $USER` | it cancels every job you own, this session's own job too |
| `git push` | it publishes your work outside Delta |

## What decides: two files in this workspace

- opencode reads `opencode.json`: the rules sit under `agent`, `workshop`, `permission`, with
  `bash` for commands and `edit` for file edits. The last rule that matches a command wins,
  and each command of a pipe or a chain (`a | b`, `a && b`) is checked on its own.
- Claude Code reads `.claude/settings.json`: `permissions` holds the `allow`, `ask` and `deny`
  lists, and a deny always wins. Claude Code asks for any command its lists do not name, so
  a look marked "opencode only" above asks you there.

At a prompt you answer Allow once, Allow always (until opencode restarts) or Reject; quick
card §3 has the details.

## Why the workshop's map is stricter than your own

This workspace runs on a shared machine, for about 50 people at once, with one shared model
key. A deleted folder or a cancelled session costs you the morning, a printed key exposes
everyone who uses it, and a job outside the caps takes GPUs from the room. So the agent
submits only through `ws-submit`, which is `sbatch` with the workshop's checks: the forced
account and partition, the caps (1 GPU, 15 minutes), your approved plan, the open-ended
budget of 10 jobs, and a record of every job. Every submission prints the `sbatch` command
it runs; an LLMFlux run prints its `llmflux` command, and LLMFlux calls `sbatch` itself.

## Your own machine or project

Leave this workspace's files as they are today: loosening them removes the checks that
protect the room. "Allow always" lasts only until opencode restarts.

For your own project, you write the map:

1. Start from "Starter permissions" in `ON-YOUR-OWN.md`.
2. Allow read-only patterns, such as `ls *`, `git diff*` and `squeue*`.
3. Keep edits, installs and submissions on ask.
4. Deny what cannot be undone or shows a secret: recursive deletes, environment dumps, key
   files.
5. Edit the `permission` block (opencode) or the three lists (Claude Code), then restart the
   harness so it reads the new map.
