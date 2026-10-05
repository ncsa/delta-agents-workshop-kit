# room: material for the room on Oct 5

These files are for staff and participants in the room. They are not part of
the workspace template, and `ops/publish-ro-copy.sh` does not copy them into
the read-only kit. Print them, or open them on a second screen.

| File | For | What it holds |
|---|---|---|
| `quick-card.md` | Every participant | One page: the Open OnDemand form values, the three commands that start the agent, what the approval prompt means, what to do when the model stops answering, and how to get help (the agent first; helpers walk the room). |
| `helper-sheet.md` | Helpers | The triage table: symptom, cause, fix, and whom to escalate to. It starts with what is expected and not a fault. |

## The take-home guide (staff copy)

`workspace-template/ON-YOUR-OWN.md` is in every participant's workspace; the agent
points to it in M8, and M7's scaffolding of `open/` follows its steps. It is not
copied here, so there is one source. Staff use it two ways:

- **Handout:** print it for anyone who wants to take the steps home on paper.
- **Slide source:** its first table (what this workspace's scaffolding did, and what
  you use on your own) is the scaffolding slide, and its bootstrap steps are the M7
  intro.

## Fill in at go-live

Before printing, replace every `<code>` with the allocation code (the workshop's allocation).

The workshop runs in `<reservation>`, a magnetic reservation Delta ops created for
both workshop days (Mon Oct 5 09:00 to Tue Oct 6 12:00) on `cn[001-002]` (cpu)
and `gpub[004-005]` (gpuA40x4, 4 A40 each). Magnetic means Slurm places every
job of `<code>-delta-cpu` and `<code>-delta-gpu` in it without `--reservation`, so
the quick card leaves the Code Server's Reservation field empty, and a job it
has no room for starts outside it in the general queue. Read it before
printing:

```bash
scontrol show reservation <reservation>
```

`Flags` must include `MAGNETIC`, `Accounts` must list both workshop accounts, `Nodes`
must be the four nodes above, and `StartTime`-`EndTime` must cover 10:00-11:45 on
Oct 5. `ops/go-live.sh --res-magnetic <reservation>` checks the same; the published
`workshop.env` has `WS_RES_MAGNETIC="<reservation>"` and empty `WS_RES_CPU` and
`WS_RES_GPU`.

At 09:00 on Monday, submit one small CPU job and one small GPU job on the workshop
accounts, without `--reservation`, and see where they land:

```bash
sbatch -A <code>-delta-cpu -p cpu -c 1 --mem=1g -t 00:03:00 --wrap 'hostname; sleep 60'
sbatch -A <code>-delta-gpu -p gpuA40x4 --gpus-per-node=1 -c 1 --mem=4g -t 00:03:00 --wrap 'nvidia-smi -L; sleep 60'
squeue -u $USER -o '%i %T %P %N %v'
```

The CPU job must run on `cn001` or `cn002` and the GPU job on `gpub004` or
`gpub005`, both with `<reservation>` in the last column (`%v`, the reservation).
`ops/README.md`, "The workshop reservation", explains how to tell whether jobs
spill into the general queue once the four nodes are full.
