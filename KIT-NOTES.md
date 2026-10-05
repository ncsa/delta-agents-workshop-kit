# ws-agents-kit

The workshop kit for the NCSA Regional Workshop on AI session "Getting started
using AI agents for research/HPC" (Delta, Mon 2026-10-05, 10:00-11:45). Each
participant runs an agentic CLI (opencode via `module load hpc-gpt`, or their
own Claude Code, Codex, Gemini or Copilot) on a Delta compute node. A
harness-agnostic `AGENTS.md` makes the agent a guide and collaborator; the
deterministic `ws-*` helpers carry the mechanics (clock, caps, submission,
checks).

(The design notes, plan and decision log this file refers to are internal and not part of this repository.)

## Layout

| Path | What it holds |
|---|---|
| `env.sh` | Sourced by participants: loads `workshop.env`, exports `WS_*`, puts `bin/` on `PATH`. |
| `workshop.env.example` | Every operator setting with a one-line comment; copy to `workshop.env` (not in git). |
| `bin/` | The helpers: `ws-init`, `ws-status`, `ws-progress` (C1); `ws-submit`, `ws-wait`, `ws-log`, `ws-cancel` (C2); `ws-check` (C3/C4); `ws-agent` (C5); `ws-preflight`, `ws-roster` (C6); `ws-standby` (C7); `ws-models` (C16). |
| `ops/` | Lead-only scripts (never published): reports directory, data staging, publishing the read-only copy; order of operations in `ops/README.md`. |
| `lib/ws-common.sh` | Shared shell library every helper sources: messages, exit codes, env loading, clock, workspace lookup, JSON strings. |
| `workspace-template/` | What `ws-init` copies into `$HOME/ws-<date>`: `AGENTS.md` and shims, `guide/` (one file per module), `topics/`, `ON-YOUR-OWN.md` (the take-home guide), and the `.in` templates. |
| `tests/` | pytest suite with fake Slurm commands in `tests/shims/`; `tests/run-checks.sh` runs everything. |
| `VERSION` | Kit version; `ws-init` records it in `.ws/kit-version`. |
| `data/`, `models/`, `containers/` | Pre-staged data (not in git; staged by `ops/stage-data.sh`, C6). |

## How a participant starts

Inside a Code Server job (or an `srun --pty bash` shell) on the workshop CPU
reservation, run these commands, then type `start` in the agent:

```bash
source /work/hdd/<code>/ws-kit/env.sh && ws-init
cd ~/ws-2026-10-05
hpc-gpt        # or opencode; claude, codex, gemini if you have one (guide/BYO-HARNESS.md)
```

`ws-init` creates `$HOME/ws-2026-10-05` (git-initialised, with `PROGRESS.md`,
`PLAN.md` and `.ws/`); on a login node it also prints the `srun` line for a
compute-node shell (C19). Its `opencode.json`
makes `workshop` the default agent and offers only the vetted Lumen models
(`WS_LUMEN_MODELS`, provider `lumen`) with the key `WS_LUMEN_KEY` picks: the
NCSA key of the `hpc-gpt` module, a personal `~/.config/lumen/key`, or a
workshop key (ops/README.md "Lumen keys and models"). `ws-models` shows which
models answer. `ws-agent` remains an optional shortcut for `cd` + `hpc-gpt`.

## Workspace files the helpers share

| File | Written by | Content |
|---|---|---|
| `.ws-workspace` | `ws-init` | Marker; helpers find the workspace by walking up from `$PWD` (or use `$WS_HOME`). |
| `.ws/kit-manifest.sha256` | `ws-init` | `sha256  relative/path` of every kit file copied; `--refresh-kit` replaces a file only while it still matches. |
| `.ws/kit-version` | `ws-init` | The kit `VERSION` the workspace was last synced with. |
| `.ws/jobs.tsv` | `ws-init` (header), `ws-submit` (rows) | `jobid<TAB>time<TAB>script<TAB>topic<TAB>effective<TAB>kind` (`gpu` or `cpu`; older rows have five columns). |
| `PROGRESS.md` | `ws-init`, `ws-progress`, `ws-submit` | Header fields (`topic:`, `backend:`, `harness:`), `## Checkpoints`, `## Jobs`, `## Notes`. |

## Publishing the read-only copy (C6)

The lead publishes a read-only copy to `/work/hdd/<code>/ws-kit/` with
`ops/publish-ro-copy.sh`: setgid, group `delta_<code>`,
`g+rX,g-w,o-rwx`, key files 0640, plus `workshop.env` and the staged
`data/`, `models/` and `containers/` (`ops/stage-data.sh`). Participants only
ever read that copy. Before Oct 2 each participant runs `ws-preflight` on a
login node; `ws-roster` tabulates the reports. See `ops/README.md`.

## Development

Create the dev environment once, then run the checks:

```bash
python3 -m venv .venv-dev
.venv-dev/bin/python -m pip install pytest shellcheck-py
tests/run-checks.sh
```

The tests run every helper against a temporary `HOME` and the fake `squeue`,
`sacct`, `scontrol` and `hostname` in `tests/shims/`; they never submit a job.
Rehearse the clock with `WS_FAKE_NOW=10:40 ws-status`.

## Contract plan

| Contract | Scope | Target |
|---|---|---|
| C1 | `lib/ws-common.sh`, `ws-init`, `ws-status`, `ws-progress`, `env.sh`, workspace template (AGENTS.md, guides, shims, templates), tests | Sep 28 |
| C2 | `ws-submit` (caps, dry run, `--via llmflux`), `ws-wait`, `ws-log`, `ws-cancel`, a test per cap | Sep 28-29 |
| C3 | Topics `ml-gpu` and `pinn`: code, sbatch, `analyze.py`, `check.sh`, null/oracle anchors | Sep 29 |
| C4 | Topics `llm-batch` and `compile-parallel`, `tailor`/`open-ended`, `lib/check-common.sh`, `ws-check` | Sep 29-30 |
| C5 | `opencode.json.in`, workshop prompt, `.opencode/command/*`, `.claude/`, `ws-agent` | Sep 29 |
| C6 | `ws-preflight`, `ops/stage-data.sh`, `ops/publish-ro-copy.sh`, reports dir, reservation text | Sep 30 |
| C7 | Standby backend: `serve.sbatch`, venv build, `ws-standby` | Sep 30-Oct 1 |
| C8 | `dryrun/`: D0 smoke, simulate, score, personas; the D0 run | Sep 30-Oct 1 |
| C9 | Guide prose and room pieces to the docs style guide | Oct 1-2 |
| C10 | Headless dry runs, model decision, human pilot, fixes, republish | Oct 1-4 |
