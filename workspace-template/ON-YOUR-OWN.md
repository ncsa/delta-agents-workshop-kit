# On your own: an agent for your own project

This workspace served fifty people for one morning on a shared machine. Here
is what you set up yourself, from an empty directory, plain `sbatch` included;
your `open/` folder from M7 is a worked example.

## What this workspace's scaffolding did for you

| Piece | What it did here | What you use on your own |
|---|---|---|
| `AGENTS.md` | 36 house rules, each with its reason | A 20- to 30-line AGENTS.md (below) |
| `guide/` and `topics/` | The session script by module; prepared code and checkers | Your README and your tests |
| `ws-submit`, `ws-check` and the helpers | `sbatch` with the workshop's checks (account, partition, 1 GPU, 15 minutes); graded evidence | `sbatch` (below) behind a prompt, caps in AGENTS.md; the kit's `bin/` to adapt |
| `ws-init` and the read-only kit | One workspace for fifty people | `git init`, your own repository |
| `PLAN.md` and its `approved:` line | No job before you approved the plan | A PLAN.md you approve by typing |
| `PROGRESS.md` and `ws-progress` | The agent's memory across resets and harnesses | A PROGRESS.md the agent appends to |
| `opencode.json`, `.claude/settings.json` | What ran without asking; deletes, dumps and dotfile edits denied | A short permissions file (below) |
| The reservation and the Lumen key | Nodes and models for one morning | The normal queue and your own key |

## Bootstrap an agent session in an empty directory

1. `mkdir my-project && cd my-project && git init`; put `.venv/` and
   `slurm-*.out` in `.gitignore`.
2. Start the harness there (`hpc-gpt`, `opencode` or `claude`), on a compute
   node or your own machine: it reads that directory's AGENTS.md.
3. Ask it to draft AGENTS.md from a few lines: the project, the language,
   how you test it, where it runs. Once code exists, `/init` drafts
   one from the code (never in the workshop workspace: it rewrites the house
   rules).
4. Add the HPC rules from the starter below.
5. Add a permissions file (below) before real work.
6. Set up the environment (below); its two lines go into AGENTS.md.
7. Write PLAN.md with the agent before code changes: the goal, your choices,
   each milestone with the line that proves it. Approve it yourself; ask for
   one PROGRESS.md line per finished milestone.
8. Commit after every step that works; read `git diff` before anything runs.
9. Verify a number before you trust it (the evidence rules below).

## A starter AGENTS.md

Replace every `<...>`; delete what does not apply:

```markdown
# <project>: agent instructions

<project> computes <what, for whom> in <language>. Before each action, say what
you will do and why; after it, show the evidence. Show `git diff` before anything runs.

## Build, test, run
- Environment: `module reset && module load <module> && source .venv/bin/activate`,
  in the same command as what needs it, and in every job script.
- Tests: `<test command>` passes before any job is submitted.
- Jobs: `sbatch --account=<account> --partition=<partition> <script>.sbatch`, at most
  <N> GPU, <memory> and <minutes> per job. Submit only after I approve.

## Evidence: exit 0 is not success
- Every job prints an environment line (host, job id, GPU, module), then `KEY: value`
  lines, then `RESULTS_OK` as its last line.
- A number counts only when `sacct` shows COMPLETED on the right partition and the
  number is in the log of the job id quoted next to it: <the result that matters>.
- PROGRESS.md: one line per finished step, with job ids and numbers. Re-read it first.

## Hard rules, each with its reason
- No compute on login nodes: they are shared for editing and submitting.
- Never print secrets or key files, even to show they exist: logs and chats are kept.
- Never edit dotfiles (`~/.bashrc`, `~/.ssh`, `~/.config`): they affect every session.
- Never `rm -rf`; delete single files only with my approval: it asks nothing first.
- Never `pip install --user`: the module sets `PYTHONNOUSERSITE=1`; use `.venv`.
- Cancel only job ids you submitted; never `scancel -u`: it cancels every job you own.
- Facts about Delta come from the docs or a command: memory goes stale.
```

## Starter permissions

Allow read-only commands; edits, installs and submissions ask; deny what
cannot be undone or shows a secret. For opencode, in `opencode.json` (the last
matching rule wins; each command of a pipe is matched on its own):

```jsonc
{
  "permission": {
    "edit": "ask", "webfetch": "ask",
    "bash": {
      "*": "ask",
      "ls *": "allow", "cat *": "allow", "grep *": "allow",
      "git status*": "allow", "git diff*": "allow", "git log*": "allow", "quota*": "allow",
      "squeue*": "allow", "sacct*": "allow", "sinfo*": "allow", "module avail*": "allow",
      "* > *": "ask", "* >> *": "ask", "*| tee *": "ask",
      "*rm -r*": "deny", "*rm -f*": "deny", "sh": "deny", "bash": "deny",
      "*/.bashrc*": "deny", "*/.ssh/*": "deny", "*/.config/lumen/*": "deny",
      "scancel -u*": "deny",
      "printenv": "deny", "printenv *": "deny", "env": "deny", "env *": "deny",
      "export -p*": "deny", "*/proc/*/environ*": "deny"
    }
  }
}
```

For Claude Code, in `.claude/settings.json` (a deny always wins):

```json
{
  "permissions": {
    "allow": ["Read", "Grep", "Glob", "Bash(git status*)", "Bash(git diff*)", "Bash(git log*)",
              "Bash(squeue*)", "Bash(sacct*)", "Bash(sinfo*)", "Bash(module avail*)"],
    "ask": ["Bash(sbatch*)", "Bash(scancel *)", "Bash(*pip install*)", "Bash(*-m venv *)",
            "Bash(* > *)", "Bash(* >> *)"],
    "deny": ["Bash(rm -r*)", "Bash(rm -f*)", "Bash(sh)", "Bash(bash)", "Bash(scancel -u*)",
             "Bash(*/.ssh/*)", "Bash(*/.config/lumen/*)", "Read(~/.ssh/**)",
             "Read(~/.config/lumen/**)", "Edit(~/.bashrc)", "Bash(printenv*)", "Bash(env)",
             "Bash(env *)", "Bash(export -p*)", "Bash(*/proc/*/environ*)"]
  }
}
```

## The environment: a module plus a venv

Take the framework from a module; put only small extras in a venv in the
project:

```bash
module reset && module load pytorch-conda/2.12 && python -m venv --system-site-packages .venv
.venv/bin/pip install <small extra>
```

`--system-site-packages` keeps the module's packages (PyTorch, NumPy) visible.
Install where you work, never inside a job: a job starts from a fixed
environment. In a job: the same `module load`, then
`source .venv/bin/activate`. PyTorch and vLLM come from modules: a pip copy
duplicates gigabytes in your home. Use conda only when no module has your
CUDA or PyTorch version.

`pip install --user` appears to succeed on Delta, but the import fails: the
Python modules set `PYTHONNOUSERSITE=1`, so `~/.local` never reaches `sys.path`.

Compiled code needs no venv: on Delta, `module reset` gives the `cc`, `CC`
and `ftn` wrappers (GCC, Cray MPICH). Build inside the job and launch with
`srun`. On another cluster, `module avail` lists its compilers and MPI.

## Jobs without the workshop's helpers

On Delta you submit with plain `sbatch`, then follow the job:

```bash
sbatch --account=<account> --partition=<partition> --time=00:15:00 job.sbatch
squeue -u $USER
sacct -j <id> -o JobID,State,ExitCode,Elapsed,NodeList,AllocTRES
scancel <id>
```

`accounts` lists your accounts (CPU and GPU); partitions include `cpu` and
`gpuA40x4` (add `--gpus-per-node=1`). A job is charged for what it reserves,
at its partition's charge factor (Delta docs). This morning `ws-submit` ran
this `sbatch` with the workshop's checks: caps, plan approval, job budget.

What stays everywhere: a plan you approve, a progress file, evidence lines,
`git diff` before each run, and a prompt before edits and jobs.

## Pointers on Delta

- Docs: https://docs.ncsa.illinois.edu/systems/delta/en/latest/ .
- `module load hpc-gpt`, then `hpc-gpt` in your project: opencode with the
  site configuration and the NCSA Lumen models.
- A personal Lumen key from lumen.ncsa.illinois.edu (NCSA login): save it as
  `~/.config/lumen/key`, mode 600. A project's `opencode.json` uses it with
  `"provider": {"lumen": {"options": {"apiKey": "{file:/u/<netid>/.config/lumen/key}"}}}`.
- The venv overlay: the section above, as in `open/.venv`.
- Questions: help@ncsa.illinois.edu.
