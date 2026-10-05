# Bring your own agent harness

The supported harness is opencode: `hpc-gpt` (or `opencode`) after
`source <kit>/env.sh`. Other agent CLIs are best effort. Whatever you use,
run it in the workspace directory (`cd ~/ws-2026-10-05`); it reads AGENTS.md
(or CLAUDE.md/GEMINI.md), and the `ws-*` helpers behave the same. A
compute-node shell is recommended (the `srun` line `ws-init` prints); a login
node works. Claude Code and Codex use their own accounts: Lumen has no
`/v1/messages` or Responses API.

**Claude Code** reads `CLAUDE.md`, which imports `AGENTS.md`. Install the
native binary into `$HOME` (Delta has no system Node.js) and sign in on a
login node before the day. Start it inside the Code Server terminal with
`cd ~/ws-2026-10-05 && claude` and type `start`. It has no Delta docs MCP
tool, so it fetches the docs site. You pay for your own tokens. Best effort:
one staff member has used it on Delta.

**Codex CLI** reads `AGENTS.md` natively (32 KiB combined cap; AGENTS.md is
under 12 KB plus one guide file at a time). It needs the OpenAI Responses API,
which Lumen does not offer, so it runs only on your own ChatGPT or API plan.
Use the standalone binary. Approvals follow its own `--ask-for-approval`
setting: keep the default and do not use full-auto. Not tested by staff.

**Gemini CLI** reads `GEMINI.md`, which imports `AGENTS.md`. It needs Node.js,
which Delta does not ship: install a portable Node LTS tarball under `$HOME`
first. Sign in with your Google account beforehand. Not tested by staff.

**Copilot CLI** reads `AGENTS.md` natively. It needs Node.js (same tarball
note) and a Copilot subscription. Its BYOK setting can point at an
OpenAI-compatible endpoint, which in principle includes Lumen, but that path
is untested here. Approvals are per command: keep them on.

**Aider** reads `.aider.conf.yml`, which loads `AGENTS.md`, `PROGRESS.md` and
`PLAN.md` read-only and turns auto-commits off. Install it into a Python venv
you own (`pip install --user` is disabled here) and bring your own API key; it
can talk to an OpenAI-compatible endpoint, but pointing it at Lumen is
untested here. It asks before each shell command it proposes: answer no to
anything that is not read-only or a `ws-*` helper. Not tested by staff.

**`/init`** (opencode, Claude Code, Codex, Gemini CLI) writes or rewrites the
AGENTS.md, CLAUDE.md or GEMINI.md of the folder it runs in. Never run it in the
workspace; use it in your own project folders (`ON-YOUR-OWN.md`).
opencode's and Claude Code's `/init` are replaced here by that pointer; in the
others nothing stops it. If it happened: `git checkout -- AGENTS.md CLAUDE.md GEMINI.md`.
