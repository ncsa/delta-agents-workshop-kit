# Topic 3: `llm-batch` — batch inference with LLMFlux

## Goal

Run 40 prompts through a small instruct model (Qwen2.5-1.5B-Instruct) as one
Slurm batch job with `llmflux run`, then measure the answer rate, how often the
answers are valid JSON, and the request latency.

## Background

1. LLMFlux wraps vLLM in an Apptainer container and writes and submits the job
   script for you; `ws-submit --via llmflux` adds the workshop's account,
   partition, reservation and caps to its command line.
2. The model weights are pre-staged as a local directory in the kit
   (`$WS_KIT_RO/models/`), so nothing downloads and no token is needed.
3. The input is the OpenAI batch JSONL format: one request per line
   (`custom_id`, `method`, `url`, `body.messages`).

## Acceptance

`ws-check llm-batch` reports level 3:

- the job COMPLETED on `gpuA40x4` in the workshop reservation when one is configured (`ws-check` skips that check otherwise), `gres/gpu=1`;
- its results file (`results/results.json`) has 40 records, at least 38 with
  a non-empty output;
- RESULTS.md has `JOBID: <that job>` and `ANSWERED:`, `JSON_VALID_RATE:` and
  `P50_LATENCY_MS:` matching what `analyze.py` computes from that file (1 %);
- `llm-batch.png` exists and is newer than the job log (`logs/<jobid>.out`).

LLMFlux owns the job log, so this topic needs no `[ws-env]` or `RESULTS_OK`
line: the evidence is the results file.

## Choices

The decisions for your plan (M2). Each has its cost and says whether the level-3 check of
`check.sh` (40 records, at least 38 answered, and the three metrics) stays as it is.

1. **Your own prompts.** Level 3 stays only if `prompts.jsonl` still holds 40 requests
   in the same format (`custom_id`, `method`, `url`, `body.messages`); write them with a
   script like `src/make_prompts.py`. About 10 minutes of writing in M4 (short on time, keep
   the prepared prompts and write your own after level 3: `TAILOR.md`, "Tailor to your
   field"), and
   `JSON_VALID_RATE:` then measures whatever format your prompts ask for. Any other
   count needs `ws-check llm-batch --tailored`: plan it as topic 5 (`tailor`), or as a
   stretch after level 3.
2. **Model size.** Qwen2.5-1.5B now: the prepared run (313.6 ms P50 latency in the
   reference). Qwen2.5-7B as a stretch after level 3 (`TAILOR.md` a): a second job with
   its own `--output`, a slower start and slower requests; `ws-check` scores the job
   whose numbers RESULTS.md cites.
3. **Generation settings** (`--max-tokens 160 --temperature 0` in `run.sh`). More tokens
   cost latency; fewer can cut a JSON answer short. Temperature 0.7 should let the
   answers change between runs (`TAILOR.md` b), but on the LLMFlux route they may not:
   in rehearsal they were identical at 0, 0.7 and 1.5. The raw vLLM route (`TAILOR.md`
   c) passes the temperature to vLLM. Both keep the results file and level 3.

## Files

| File | What it is |
|---|---|
| `prompts.jsonl` | The 40 requests (5 fields × 8 one-sentence research descriptions), each asking for `{"field", "confidence", "why"}` JSON. |
| `src/make_prompts.py` | Regenerates `prompts.jsonl`, byte for byte. |
| `models.ws.yaml.in` | LLMFlux's Qwen2.5-1.5B and 7B entries with `hf_name` = the local model directory. |
| `run.sh` | Renders `models.ws.yaml`, prints and runs the `ws-submit --via llmflux -- run ...` line; a dry run unless `--yes`. |
| `envcheck.sbatch` | One-minute job: the container starts, vLLM and the GPU are visible inside it, the model is staged. |
| `analyze.py` | `python analyze.py results/results.json`: the metric lines and `llm-batch.png`. |
| `job.rawvllm.sbatch`, `src/raw_vllm_batch.py` | The tailor: the same container and prompts with an offline vLLM script. |
| `RESULTS.md.in` | The template for RESULTS.md. |
| `TAILOR.md` | Stretch and tailor items: 1.5B vs 7B, temperature repeatability, raw vLLM, serve. |
| `reference/` | A real results file and log from the dry run: "reference run, not yours". |

## Environment

```
module reset && module load llmflux
```

`llmflux` 2.0.0 is the default. Never load it in the same shell as
`pytorch-conda` (both are Python stacks; Lmod refuses). Run from this directory:
it is LLMFlux's workspace, so `results/`, `logs/<jobid>.out` and (with
`--debug`, which ws-submit adds) the generated `job.sh` land here.

```
bash run.sh                # dry run: renders models.ws.yaml and prints the full llmflux command
bash run.sh --yes          # after approval: submits; prints "Submitted batch job N"
```

The command it runs (the design's):

```
ws-submit --via llmflux -- run --model Qwen2.5-1.5B-Instruct-local \
    --custom-config-path models.ws.yaml --engine vllm \
    --input prompts.jsonl --output results/results.json \
    --max-tokens 160 --temperature 0 --batch-size 8
```

Read-only commands after `module load llmflux`: `llmflux jobs`, `llmflux status <id>`,
`llmflux logs <id>`. Cancel with `ws-cancel <id>`.

## Pitfalls

- LLMFlux's defaults (`--partition a100`, 30 minutes) are rejected on Delta:
  always submit through `run.sh` / `ws-submit --via llmflux`, which fixes both
  and adds the reservation.
- A Hub model name (`Qwen/...`) or a gated model (`Llama-3.2-*`): the job tries
  to download and fails (`HF_TOKEN`, no network). Use the `-local` keys.
- Running `llmflux` from the wrong directory: results and logs land relative to it.
- The first container start takes 1-3 minutes; `Still loading... (60/300s)` in
  the log is normal.
- Reading `job.sh` before it exists: it appears when `llmflux run` returns.
- `pip install vllm`, or running vLLM on the harness node: never; vLLM runs in
  the job, inside the container.
- `llmflux cancel` or raw `scancel`: use `ws-cancel`.
- Reporting a number from `reference/`: that is not your job; `ws-check` knows.
