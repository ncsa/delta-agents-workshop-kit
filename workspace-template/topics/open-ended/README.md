# `open-ended`: the part after the prepared topic (M7)

Once your prepared topic reports level 3, the rest of the session is yours: ask
the agent to set up an environment and solve a small problem, watch it work,
and steer it by typing. This is not an alternative to the prepared topic; it
comes after it. Pick a suggestion from `IDEAS.md` (the one on the slide) or
bring your own. The agent starts by setting up `open/` as a small project of
its own: the steps you would take in an empty directory (`ON-YOUR-OWN.md` in
your workspace).

## Limits (all of them)

- At most 1 GPU (with up to 16 cores) or a CPU-only job of up to 16 cores;
  one node; at most two GPU jobs queued or running at a time. A CPU job
  (`ws-submit --cpu`) unless the step needs the GPU.
- At most 15 minutes of wall time per job, and at most 10 jobs from `open/`
  in all (any state): about 50 people share 8 A40s and 2 CPU nodes.
  `ws-submit` refuses the 11th, and the agent says so when the budget is used up.
  One job per iteration, each answering one question.
- Everything lives in `open/` in your workspace: `README.md`, `AGENTS.md`,
  `PLAN.md`, code, the job script, `RESULTS.md`; the logs land as
  `slurm-<id>.out` in the directory you submit from.
- Installs only inside the workspace: a venv in `open/.venv` on top of a
  module, made on the session node (where the agent runs), never inside a job.
  Heavy frameworks (PyTorch, vLLM) come from modules (`pytorch-conda/2.12`,
  `llmflux`), never from pip.
- Downloads are allowed on the session node into `open/.venv` or `open/data`:
  never inside a job, never piped into a shell.

## The job budget and steering

The agent follows these lines in M7:

- The 10 jobs are the workshop's, and `ws-submit` counts them: no approval,
  `open/PLAN.md` edit or stretch raises the number, so never offer to. It is
  not a rule of `open/AGENTS.md` either: editing that file changes nothing.
- Name the budget once, when M7 starts; do not count jobs aloud after that.
- Spend jobs so that the participant's own typed requests can still run.
- At 10 of 10, say so once, then offer job-free steps: a plot from the logs
  already there, `open/RESULTS.md`, `open/README.md`. Never compute on the
  session node to save a job.
- A prepared topic's stretch item runs in M7 only on a typed request.
- A typed steer inside the approved goal is the next iteration and needs no
  new approval. A new goal, or one the agent proposes, gets a new
  `open/PLAN.md`, approved in words.
- Never change a bar after its result: report the miss.
- One `ws-submit --yes` per reply, also after a failed job.
- A question ends the reply: never answer it yourself ("taking that as a
  yes"), and never act in the same reply.
- A job still waits: give the `squeue` reason in one line and wait again,
  with no question.

## The scaffold: `open/` as a small project

The agent writes these files first and explains each one in a line as it writes it:

- `open/README.md`: the goal and how to run it.
- `open/AGENTS.md`: only this project's rules: the module, the venv, the job
  script, the evidence line. It says that the workspace's AGENTS.md still
  applies; where the two disagree, the workspace's rules win.
- `open/PLAN.md`: the mini-plan (below), with its approval line.
- `open/.venv`: the environment (below).

Never run `/init` here: it would rewrite the workshop's AGENTS.md.

## The mini-plan: `open/PLAN.md`

Three to five lines, written with the agent and approved by you in your own
words:

1. the goal, and the number that shows it worked;
2. the environment: the module, and the extras for `open/.venv` (if any);
3. how we will know it worked: the `KEY: value` line the job prints, and the
   value that counts;
4. the resources: 1 GPU or up to 16 cores, at most 15 minutes per job.

Its last line is `approved:`, which the agent fills in once you approve in
words ("I approve"; "ok", "keep going" or a steer is not an approval).

The workspace PLAN.md you approved in M2 already lets `ws-submit` run jobs
from `open/`; the mini-plan is the agreement about this goal.

## The environment

```bash
module reset && module load pytorch-conda/2.12 && python -m venv --system-site-packages open/.venv
open/.venv/bin/pip install <one small package>
```

`--system-site-packages` keeps the module's own packages (numpy, torch,
matplotlib) visible. Prove it with a short job modelled on a topic's
`envcheck.sbatch`: `module load` the same module, then
`source open/.venv/bin/activate` inside the job, import the package, print the
`[ws-env]` line and `RESULTS_OK`. Short on time: skip the venv and use a
module as it is. A failed `pip install`: quote the error; retry once, or use
the module as it is (AGENTS.md rule 29).

## No venv: C and LLMFlux ideas

A compiled idea (5) uses `module reset` plus the compiler module, with no
venv; the first job's `[ws-env]` line and `cc --version` prove it. Compile
inside the job, never on the session node, not even as a syntax check: a
compiler there is compute outside a job, and `nvcc` has no syntax-only mode.
On the session node, `bash -n open/job.sbatch` is the only check.

An LLMFlux idea (6) runs inside LLMFlux's container: there is no venv, no
`[ws-env]` and no `RESULTS_OK`. Start with
`cp topics/llm-batch/{run.sh,models.ws.yaml.in} open/`; `bash open/run.sh`
(a dry run, then `--yes`) submits from `open/`. The evidence is the results
file: `python3 topics/llm-batch/analyze.py --metrics open/results/results.json`
prints `RECORDS` and `ANSWERED`, and `ws-check open-ended` reads the same file
(at least one answered record) instead of the log lines below.

## Inputs

An input the idea needs that is not in the workspace: ask once for a paste or
a path, naming the sample (`topics/open-ended/samples/paragraphs.md` for idea
6); on a reply without it, use the sample and say so. Never search the
filesystem for input.

## The job

Copy `job.template.sbatch` to `open/job.sbatch` and fill in the marked lines;
never write a job script from scratch: the template's `set -e` keeps
`RESULTS_OK` off a failed run. It follows `topics/LOG-PROTOCOL.md`:

1. the `[ws-env] host=... job=... gpu=... module=...` line;
2. your evidence lines, one `KEY: value` per line (upper-case key, a number
   or a word after the colon);
3. `RESULTS_OK` as the last line, only when the run succeeded.

Submit a GPU job with `ws-submit open/job.sbatch`; a CPU job (delete the
`--gpus-per-node` line, set `--mem=16g`) with `ws-submit --cpu open/job.sbatch`.

## Evidence

The same discipline as the prepared topic: the log of the quoted job id has
the `[ws-env]` line, the `KEY: value` lines and `RESULTS_OK` (LLMFlux: the
results file instead), and `open/RESULTS.md` quotes them next to that job id.
`ws-check open-ended` reads `open/RESULTS.md` and only jobs submitted from
`open/`; optional: it cannot know what your numbers mean.

## After each result

Record it with `ws-progress --note "M7: <what ran> job <id> <KEY>=<value>"`
(a note per iteration; the one `ws-progress M7` checkpoint comes with the
first result). Then say the next iteration as a statement, not a yes/no
question, for example "Next: I run the 8192 size on the GPU; type a steer.",
and stop for steering. Never propose the wrap: M7 ends when the participant
types "wrap up". A new goal updates `open/README.md`,
`AGENTS.md` and `PLAN.md` together and needs a new approval (above); show
`git diff open/`. Scratch code goes in `open/build/` (gitignored), never
`/tmp`.

## Plots

In `pytorch-conda/2.12`, text drawn on matplotlib's default Agg canvas
(titles, labels, ticks) fails with `FT_Render_Glyph ... raster overflow`:
every `.png`, and seaborn's `heatmap` and `lmplot` even when saving `.svg`
(they draw on the canvas first). `job.template.sbatch` exports
`MPLBACKEND=svg`, which leaves Agg out: save plots as `.svg` (Code Server
shows them); a `.png` fails under either backend unless the script copies
`agg_text_workaround` from `topics/pinn/analyze.py`, as the topics'
`analyze.py` do. On the session node, put the variable on the command line:
`MPLBACKEND=svg python open/plot.py`.
