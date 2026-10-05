# Reference run (not yours)

A real run of `topics/pinn/oracle.sh` on one A40 (job 22466011, 2026-09-28):
`slurm-reference.out` (the job log), `pinn-reference.png` (its plot) and
`RESULTS.reference.md` (the results written from it).

Use it only when your own job is still queued at the end of M5, to practise
M6 (`python topics/pinn/analyze.py topics/pinn/reference/slurm-reference.out --out /tmp/pinn-ref.png`)
while your job runs. Label everything from it "reference run, not yours".
Its numbers never go into your RESULTS.md, and `ws-check pinn` does not count
it: the job id is not from your workspace.
