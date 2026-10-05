# llm-batch: stretch and tailor

Only after M6 is done (level 3). Every item keeps the caps: 1 GPU, 15 minutes,
submitted through `ws-submit`. With `ws-check llm-batch --tailored` the numeric
thresholds relax (at least one record instead of 40, no minimum of answered
records): the metrics must still be in the results file and match RESULTS.md,
and the scheduler checks stay.

## a. 1.5B versus 7B (a second job)

1. `bash run.sh --model Qwen2.5-7B-Instruct-local --output results/results-7b.json`
   (dry run), then `--yes` after approval.
2. State what you expect first (rule 23): more valid JSON from the 7B? how much slower per request?
3. `python analyze.py results/results-7b.json --out llm-batch-7b.png`; compare
   `JSON_VALID_RATE:`, `FIELD_MATCH_RATE:` and `P50_LATENCY_MS:` of the two jobs
   under "What changed" in RESULTS.md, citing both job ids. `ws-check` scores the
   job whose numbers RESULTS.md cites.

## b. Temperature 0.7: how repeatable?

Two runs of the same prompts at `--temperature 0.7` (edit the `--temperature` in a
copy of `run.sh`, and give each run its own `--output`). Count the prompts whose
`field` differs between the two runs (a few lines of Python over the two results
files). Then say what temperature 0 bought you.

On the LLMFlux route the answers may not change at 0.7: in rehearsal they were
identical at 0, 0.7 and 1.5. That is the route, not a mistake. The raw vLLM route (c)
passes `--temperature` to vLLM with a fixed `--seed 1234`: compare a run at 0.7 with
one at 0, or give two runs at 0.7 their own `--seed`.

## c. Raw vLLM: what LLMFlux automates

`job.rawvllm.sbatch` runs the same container directly:
`apptainer exec --nv $LLMFLUX_CONTAINERS_DIR/llm_processor.sif python3 src/raw_vllm_batch.py ...`,
with `from vllm import LLM, SamplingParams`: no server, no port, no health poll.

1. Read `job.rawvllm.sbatch` and `src/raw_vllm_batch.py` together; find the lines that
   correspond to LLMFlux's generated `job.sh` (the bind mounts, `--nv`, the model path)
   and the parts LLMFlux adds (the server, the health poll, the retrying client).
2. `ws-submit job.rawvllm.sbatch`, then `--yes`. Its log (`slurm-<id>.out`) has
   `[ws-env]`, `LOAD_SECONDS:`, `GENERATE_SECONDS:`, the same metric lines as
   `analyze.py`, `RESULTS_FILE: .../results/raw.json` and `RESULTS_OK`.
3. Compare the latency: here each request of a batch waits for the whole batch.
   `ws-check llm-batch` reads `results/raw.json` for this job through its
   `RESULTS_FILE:` line.

## d. A server you talk to (optional, if time allows)

`llmflux serve --model Qwen2.5-1.5B-Instruct-local --custom-config-path models.ws.yaml`
submitted through `ws-submit --via llmflux -- serve ...` (it adds the caps), then
`llmflux connect <id>` and one `curl` chat request from the harness node. The lesson
is network reachability between compute nodes. Cancel it with `ws-cancel <id>` when done.

## Tailor to your field

- Your own prompts: 20-60 short requests in the same JSONL format (write them with a
  script like `src/make_prompts.py`, keep `custom_id`), and your own success rule in
  place of the JSON check. Keep the results file and `analyze.py`'s metric lines;
  check with `ws-check llm-batch --tailored`.
