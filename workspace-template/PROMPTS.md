# Prompts to try: copy one, or ask the agent to pick

Each line in a grey block is something you type to the agent as it is; fill in the angle
brackets. Or type this and let the agent choose with you:

```text
Read PROMPTS.md and suggest three things that fit what I have done so far.
```

A new plot, an explanation or a write-up costs no job. Each new run is one of the 10 jobs of
the open-ended part.

## Go deeper on your result

```text
Explain this result as you would to a new student in my lab, then say what you would check next.
```

```text
Run one more variation that tests <my idea>. Tell me first what you expect.
```

```text
Make another plot from the logs we already have: <what against what>. Save it as .svg.
```

```text
Write what we did as a one-page README I could hand to a colleague.
```

## Learn about Delta

```text
Which partitions and GPUs does Delta have, and which would you pick for this job? Use the Delta documentation.
```

```text
Why did my job wait, and how is it charged?
```

```text
How much of my quota am I using, and where should large data go?
```

```text
What would change if I ran this on my own allocation, without the workshop's helpers?
```

## A Jupyter notebook of your results

Ask the agent for the notebook:

```text
Turn the analysis into a Jupyter notebook in open/ that reads the job logs and redraws the plots. Use matplotlib.use('svg') and show each figure with IPython.display.SVG.
```

The SVG wording matters: in this Python module a notebook's default plots fail with a
"raster overflow" error, and figures drawn with the SVG backend work.

Then register a Jupyter kernel. **You type this yourself, in a terminal, once** (it writes
to your home directory, outside the workspace, so it is not the agent's to run). With the
module's packages only:

```bash
module reset && module load pytorch-conda/2.12 && setup-jupyter-kernel.py --kernel-name workshop --display-name "Python (workshop)"
```

Or, from your workspace folder, with the extras the agent installed into `open/.venv`:

```bash
module reset && module load pytorch-conda/2.12 && source open/.venv/bin/activate && setup-jupyter-kernel.py --kernel-name workshop-venv --display-name "Python (workshop + my venv)"
```

That second form is a Delta pattern worth keeping: the framework (PyTorch) comes from a
module, small extras go into a venv made with `--system-site-packages`, and the venv is
registered as the kernel, so a notebook sees both.

Open the notebook in a second Open OnDemand session: Interactive Apps, Jupyter Lab, with the
account and partition from the quick card and the reservation left empty. Open the file from
your workspace folder and pick the kernel you named.

## Another prepared topic

Start fresh in a second folder; the first workspace stays as it is. In a terminal:

```bash
WS_HOME=~/ws-second ws-init
cd ~/ws-second
hpc-gpt
```

Then type `start` and choose another topic from the menu.

## Toward your own project

```text
Read ON-YOUR-OWN.md and draft an AGENTS.md for my own project: <two sentences about it>. Put it in open/my-project/.
```

```text
What are you not allowed to do here, and which file says so?
```

Type `/models`, pick another model, and ask it the same question again: compare the answers.
