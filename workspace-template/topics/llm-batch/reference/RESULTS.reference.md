# Results: llm-batch

JOBID: 22511402

## Evidence

Printed by `python analyze.py results/results.json` for that job's results file:

- results file: results/results.json
- job log: logs/22511402.out
- ANSWERED: 40
- JSON_VALID_RATE: 1.0000
- P50_LATENCY_MS: 313.6
- plot: `llm-batch.png`

## What changed

none: the oracle runs run.sh unchanged (Qwen2.5-1.5B-Instruct-local, temperature 0, 160 tokens, batch size 8).

## How it was verified

sacct: 22511402|COMPLETED|0:0|00:02:06|gpub063|gpuA40x4||billing=500,cpu=8,gres/gpu=1,mem=32G,node=1; numbers from python3 analyze.py --metrics results/results.json; ws-check llm-batch below.

## One limitation

One model and one run of 40 prompts at temperature 0; the latency includes queueing inside LLMFlux's client batches.
