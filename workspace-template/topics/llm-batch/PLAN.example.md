# Plan

participant: <user> · date: <date> · topic: llm-batch

The example plan: the agent's reference for a sound plan.

## Goal

Run the 40 prompts of `topics/llm-batch/prompts.jsonl` through Qwen2.5-1.5B-Instruct with
`llmflux run` on one A40 and find out how many it answers, how often as valid JSON, and how fast,
proven by `ANSWERED:`, `JSON_VALID_RATE:` and `P50_LATENCY_MS:` from the job's results file.

## Choices

1. Prompts: the prepared 40. Why: the checker expects 40 records. Cost: none.
2. Model: Qwen2.5-1.5B now; the 7B model only after level 3. Why: the 1.5B run is the
   calibrated one and starts faster. Cost: the 7B job is one more job, only if time allows.
3. Generation settings: `--max-tokens 160 --temperature 0`, as prepared. Why: repeatable answers
   that fit the JSON. Cost: none.

## Milestones

1. M3 environment: `ws-submit topics/llm-batch/envcheck.sbatch`, then `--yes`.
   Evidence: the log shows `[ws-env] ... gpu=NVIDIA A40`, `MODEL_STAGED: yes`,
   `CUDA_AVAILABLE: True` and `RESULTS_OK`.
2. M4-M5 job: `bash run.sh` (a dry run: the full llmflux command), then `bash run.sh --yes`.
   Evidence: `sacct` shows COMPLETED on gpuA40x4 in the reservation with `gres/gpu=1`;
   `results/results.json` has 40 records, at least 38 answered.
3. M6 results: `python analyze.py results/results.json` writes `llm-batch.png`; RESULTS.md
   cites the job id.
   Evidence: `ws-check llm-batch` reports level 3.

## Rules for this project

- Load `llmflux` alone, never with `pytorch-conda` in the same shell: Lmod refuses the pair.
- Submit only through `run.sh` (`ws-submit --via llmflux`): LLMFlux's own defaults are rejected
  on Delta.
- Use the `-local` model keys: a Hub name tries to download and fails in the job.

## Approval

approved:
