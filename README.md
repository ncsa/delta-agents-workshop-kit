# Delta agents workshop kit

The participant kit from the session "Getting Started Using AI Agents for Research/HPC" at the NCSA
Regional Workshop on AI (Mon 2026-10-05), run on NCSA's Delta supercomputer. About 50 researchers each
worked with a coding agent on a compute node: first a prepared topic taken to a checked result, then an
open-ended problem of their own.

This repository is the kit as published to participants that morning. It is shared as a worked example of
how to scaffold an agent for hands-on work on a shared HPC system; it is not a product, and it does not run
unchanged anywhere but Delta.

## What is in it

| Path | What it is |
|---|---|
| `workspace-template/` | What each participant's workspace starts from |
| `workspace-template/AGENTS.md` | The house rules every agent harness reads first: how to work, what never to do, and why |
| `workspace-template/guide/` | One short script per session module (launch, orient, plan, environment, build, run, analyze, open-ended, wrap) |
| `workspace-template/topics/` | Four prepared topics (GPU training, a physics-informed network, LLM batch inference, compiled OpenMP/MPI code), each with a job script and a checker, plus the open-ended part |
| `workspace-template/PERMISSIONS.md` | What the agent runs freely, what asks first, what never runs, and which files decide |
| `workspace-template/FAQ.md`, `PROMPTS.md` | Short answers the agent starts from; prompts for going further |
| `workspace-template/ON-YOUR-OWN.md` | The take-home guide: setting up an agent for your own project from an empty directory |
| `workspace-template/opencode.json.in`, `.claude/` | The permission maps for opencode and Claude Code |
| `bin/`, `lib/` | The `ws-*` helper scripts: `ws-init` (make a workspace), `ws-submit` (`sbatch` with the workshop's checks), `ws-wait`, `ws-log`, `ws-check`, `ws-status`, `ws-progress` and others |
| `room/` | The participants' quick card and the helpers' triage sheet |
| `env.sh`, `workshop.env.example` | The environment a participant sources, and every operator setting with a comment |
| `KIT-NOTES.md` | The kit's internal README, unedited: layout and conventions (it mentions tests and operator scripts that are not in this repository) |

## Start here

- To see how the agent was instructed: `workspace-template/AGENTS.md`, then `workspace-template/guide/01-orient.md`.
- To set up an agent for your own project: `workspace-template/ON-YOUR-OWN.md`. It has a starter `AGENTS.md`,
  starter permissions for opencode and Claude Code, the module-plus-venv environment pattern, and plain
  `sbatch` without the workshop's helpers.
- To reuse a helper: the scripts in `bin/` are plain bash with a shared library in `lib/ws-common.sh`.

## What it assumes

- **Delta**: Slurm, Lmod modules (`pytorch-conda/2.12`, `llmflux`), the `cpu` and `gpuA40x4` partitions, and
  NCSA's `hpc-gpt` module (opencode with the NCSA Lumen model service).
- **A staged read-only copy** with data, two small models and a container, which are not in this repository.
- **Operator settings** in a `workshop.env` rendered from `workshop.env.example`: accounts, partitions, a
  reservation, the model list. `<code>` in the text stands for the workshop's allocation code, and
  `/path/to/site-lumen-key` for the site's model-service key file.

To adapt it to another cluster, expect to change the settings file, the module names in the topics' job
scripts, and the Delta facts in `AGENTS.md`, `FAQ.md` and the room cards.

## What is not here

The test suite, the dry-run simulator used to rehearse the session with scripted participants, and the
operator scripts for staging and publishing are not in this repository.

## Design choices worth knowing

- **One file of rules, with reasons.** `AGENTS.md` is kept under 12 KB and every hard rule says why.
- **Evidence before claims.** A job counts only with its `KEY: value` evidence line in the log and the
  scheduler's record; `ws-check` grades that, and exit 0 is not success.
- **A plan the participant approves in words** before anything is submitted.
- **Permissions by the harness, not by the model.** The examples in `PERMISSIONS.md` were tested against
  the real permission map.
- **No session clock.** The facilitator paces the room; every module ends with what happened, two questions
  the participant might ask, and the next step with what to type.

## License

Apache License 2.0; see `LICENSE`. Provided as is, without warranty.

## Contact

Questions about Delta: help@ncsa.illinois.edu. Delta documentation:
https://docs.ncsa.illinois.edu/systems/delta/en/latest/
