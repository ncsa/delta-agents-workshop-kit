# Quick card: AI agents on Delta, Oct 5

Keep this page open for the whole session.

The workshop models run on NCSA Lumen under a shared key (the one the `hpc-gpt` module ships,
unless you use your own), and what you type is sent to them. Do not paste sensitive or
regulated data: student records, health data, export-controlled or other restricted
material, passwords or keys.

## 1. Launch Code Server (Open OnDemand)

Go to Open OnDemand, then Interactive Apps, then Code Server, and fill in the form:

| Field | Value |
|---|---|
| Account | `<code>-delta-cpu` |
| Partition | `cpu` (not `cpu-interactive`: it caps a job at 1 hour) |
| Reservation | leave it empty: jobs on the workshop account go to the reserved workshop nodes on their own |
| CPUs | 2 |
| Memory | 4 GB |
| GPUs | 0 |
| Duration | `1:45` (1 hour 45 minutes; a relaunch uses 1:45 again) |

Click Launch, wait for Connect, then open a terminal (menu: Terminal, New
Terminal).

## 2. Start the agent

Type these commands in the terminal, one at a time:

```bash
source /work/hdd/<code>/ws-kit/env.sh && ws-init
cd ~/ws-2026-10-05
hpc-gpt
```

No Code Server? ssh to a login node and run the first command there. `ws-init`
prints an `srun` line: paste it to get a shell on a compute node (it may wait a
minute), then type the last two commands (`cd …`, `hpc-gpt`) in that shell. The
login node also works if the `srun` line waits too long.

Instead of `hpc-gpt` you may start `opencode`, or `claude`, `codex` or `gemini` if you
have one (your own account; see `guide/BYO-HARNESS.md`). Always start it in
`~/ws-2026-10-05`. When the agent screen appears, type `start` and press Enter.

**The flow: a prepared topic, then an open-ended part.** First you and the agent take
one prepared topic to level 3 (a real job, checked). The agent ends each milestone with
what happened, two questions you might ask, and what comes next; type `go` to continue.
The facilitator calls the times for the room. The open-ended part (M7) starts
with the agent scaffolding `open/` as a small project of its own (`README.md`,
`AGENTS.md`, `PLAN.md`), the steps you would take in an empty directory; then it sets up
an environment and solves a problem of your own, or one from the slide. You watch it
work and steer it. When a result is in, the agent says what it runs next; steer it or
say "go on". Each job answers one question, and M7 has a budget of 10 jobs (about 50
people share 8 GPUs and 2 CPU nodes). When the facilitator calls the wrap, type `/wrap`
(other harnesses: `wrap up`).

**M2 is where you plan.** You choose a topic, read its code and its checker with
the agent, make one or two choices, and approve `PLAN.md` in your own words. No job runs
before that. After that the agent works through each milestone and explains as it goes;
it stops at the end of each one and continues on your next message.

**Steer by typing.** You can type anything at any time: a question, or your own request.
The agent does it when it fits your plan and the workshop rules, or says which rule it
conflicts with and offers the closest step. Type **slow down** for one step per reply
(**go ahead** to return to the normal pace).

**A block headed "Compaction"** may appear in a long session: the agent condensed the
conversation to fit the model's context window (its working memory). Your files, `PLAN.md`
and `PROGRESS.md` are unchanged; carry on.

> **Use your own Lumen key (optional).** Get a personal API key from NCSA Lumen
> (lumen.ncsa.illinois.edu, your NCSA login), then save it and rerun `ws-init`:
>
> ```bash
> mkdir -p ~/.config/lumen && cat > ~/.config/lumen/key   # paste the key, Enter, Ctrl-D
> chmod 600 ~/.config/lumen/key
> ws-init
> ```
>
> The `lumen key:` line in `PROGRESS.md` then says `personal`. Restart the agent.

## 3. The approval prompt

The agent asks before it runs a command that changes something: a job
submission, a file edit, a permission change. The prompt shows the exact
command.

You have three choices:

- **Allow once**: this command runs, and the next one asks again.
- **Allow always**: a second screen lists the patterns it will allow until
  opencode restarts; confirm only for read-only commands.
- **Reject**: the command does not run, and the agent offers another way.

(Claude Code: Yes / Yes, and don't ask again / No.)

Read the command before you answer. The prompt is your one chance to stop a
wrong command. Never allow everything.

`PERMISSIONS.md` in your workspace shows what runs freely, what asks, what never
runs, and what controls it.

## 4. When the model stops answering

A red "Upstream error", or a reply that stops in the middle of a step: type
`continue` once (the agent checks `PROGRESS.md` and the queue before it repeats
anything). A pause of about a minute while it retries is a rate limit: wait,
and do not switch `/models` for one; switch only after two failures in a row.

No reply for 2 minutes, or a "stream error":

1. Press **Esc**, then send your last message again, once.
2. Still nothing: type `/models` and choose the next model on the list
   (**qwen3.8-27b**, then **qwen3.8-flash**).
3. Both silent: **Workshop standby**, but only when `ws-standby status` shows
   it up. Open a second terminal and run:

   ```bash
   source /work/hdd/<code>/ws-kit/env.sh
   ws-standby status
   ```

4. To see which Lumen models answer with your key, in that terminal:
   `cd ~/ws-2026-10-05 && ws-models`. "No access to this model": pick
   another with `/models`.

The agent picks up from `PROGRESS.md`, so no work is lost. If both backends
are down, stop a helper as they walk past.

## 5. Getting help

Ask the agent first: it can explain an error, the queue, a command or a step,
and asking it is part of working with an agent. Ask anything, at any time: "why
did that job wait?", "can I use my own data?", "how does the approval prompt
work?", "how do I see this plot on my own computer?", or "where are we?" for
the module and the next step. `FAQ.md` in your workspace has the short
answers the agent starts from. `PROMPTS.md` has prompts to copy when you want
to go further (a second plot, questions about Delta, a Jupyter notebook,
another topic). Helpers walk the room; stop
one as they pass for Duo or login trouble, a Code Server session that stays
queued, a job that stays queued for many minutes, a quota error, or a broken module.
Ask the agent "what do I tell the helper?" and it writes your NetID, the job id
and the error line.

## After the session

The agent points you to `ON-YOUR-OWN.md` in M8: the take-home guide in your workspace.
It shows what you set up yourself for your own project, starting from an empty
directory, with a starter AGENTS.md and permissions; your `open/` folder is a worked
example. In your own project folder (never in `~/ws-2026-10-05`) your harness's `/init`
drafts an AGENTS.md from the code. The kit is at `/work/hdd/<code>/ws-kit`.
