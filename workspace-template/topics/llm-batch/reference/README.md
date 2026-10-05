# Reference run (not yours)

A real run of `topics/llm-batch/oracle.sh` on one A40 (job 22511402, 2026-09-28):
`results.reference.json` (the results file), `llm-batch-reference.out` (the job
log), `llm-batch-reference.png` and `RESULTS.reference.md`. Paths in them are
shortened to `$HOME` and `$WS_KIT_RO`.

Use it only when your own job is still queued at the end of M5, to practise
M6 (`python topics/llm-batch/analyze.py topics/llm-batch/reference/results.reference.json --out /tmp/llm-batch-ref.png`)
while your job runs. Label everything from it "reference run, not yours".
Its numbers never go into your RESULTS.md, and `ws-check llm-batch` does not
count it: the job id is not from your workspace.
