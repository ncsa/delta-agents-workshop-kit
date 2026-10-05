# Reference run (not yours)

A real run of `topics/compile-parallel/oracle.sh` on 16 cores of the `cpu`
partition (job 22511559, 2026-09-28): `slurm-reference.out` (the job log),
`scaling-reference.png` and `RESULTS.reference.md`. Paths in them are shortened
to `$HOME` and `$WS_KIT_RO`.

Use it only when your own job is still queued at the end of M5, to practise
M6 (`python topics/compile-parallel/analyze.py topics/compile-parallel/reference/slurm-reference.out --out /tmp/scaling-ref.png`)
while your job runs. Label everything from it "reference run, not yours".
Its numbers never go into your RESULTS.md, and `ws-check compile-parallel` does
not count it: the job id is not from your workspace.
