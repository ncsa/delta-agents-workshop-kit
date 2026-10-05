#!/usr/bin/env python3
"""The llm-batch prompts through vLLM's offline engine: what LLMFlux automates, by hand (TAILOR.md).

Runs INSIDE the LLMFlux container (job.rawvllm.sbatch: `apptainer exec --nv .../llm_processor.sif
python3 src/raw_vllm_batch.py ...`), because that is where vLLM is installed. No server, no port:
`vllm.LLM` loads the local model directory into the GPU and `LLM.chat` generates for a batch of
conversations. Temperature 0 and a fixed seed make it deterministic.

Writes the results file in LLMFlux's record shape ({input, output, metadata{model, timestamp,
request_latency_ms, retry_count}}, output as an OpenAI chat completion), so analyze.py and ws-check read
it the same way. Latency: the prompts go in batches of --batch-size; every request of a batch gets the
batch's wall time (they finish together), which is what a client of this batch would wait.

Prints the log protocol lines: `MODEL:`, `LOAD_SECONDS:`, `GENERATE_SECONDS:`, analyze.py's metric lines
(`ANSWERED:`, `JSON_VALID_RATE:`, `P50_LATENCY_MS:`, ...), `RESULTS_FILE:` and, last, `RESULTS_OK`.

    python3 src/raw_vllm_batch.py --model <local model dir> --prompts prompts.jsonl --out results/raw.json
"""
import argparse
import datetime
import json
import sys
import time
import uuid
from pathlib import Path

TOPIC = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOPIC))
import analyze  # noqa: E402  (the topic's analyze.py: the same metrics as ws-check)


def main():
    ap = argparse.ArgumentParser(description="Offline vLLM batch over prompts.jsonl (inside the LLMFlux container).")
    ap.add_argument("--model", required=True, help="local model directory (config.json, *.safetensors)")
    ap.add_argument("--prompts", default="prompts.jsonl")
    ap.add_argument("--out", default="results/raw.json")
    ap.add_argument("--max-tokens", type=int, default=160)
    ap.add_argument("--temperature", type=float, default=0.0)
    ap.add_argument("--batch-size", type=int, default=8)
    ap.add_argument("--seed", type=int, default=1234)
    args = ap.parse_args()

    model = Path(args.model)
    if not (model / "config.json").is_file():
        sys.exit(f"{model}/config.json is missing: pass the staged local model directory (nothing downloads)")
    items = [json.loads(l) for l in Path(args.prompts).read_text().splitlines() if l.strip()]
    print(f"MODEL: {model}", flush=True)
    print(f"PROMPTS: {len(items)}", flush=True)

    from vllm import LLM, SamplingParams

    t0 = time.perf_counter()
    llm = LLM(model=str(model), seed=args.seed, max_model_len=4096, gpu_memory_utilization=0.85,
              enforce_eager=True)
    print(f"LOAD_SECONDS: {time.perf_counter() - t0:.1f}", flush=True)
    params = SamplingParams(temperature=args.temperature, max_tokens=args.max_tokens, seed=args.seed)

    records = []
    t_gen = time.perf_counter()
    for start in range(0, len(items), args.batch_size):
        batch = items[start:start + args.batch_size]
        t1 = time.perf_counter()
        outs = llm.chat([it["body"]["messages"] for it in batch], params, use_tqdm=False)
        ms = (time.perf_counter() - t1) * 1000.0
        for it, o in zip(batch, outs):
            c = o.outputs[0]
            records.append({
                "input": it,
                "output": {
                    "id": str(uuid.uuid4()),
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": str(model),
                    "choices": [{"index": 0, "message": {"role": "assistant", "content": c.text},
                                 "finish_reason": c.finish_reason}],
                    "usage": {"prompt_tokens": len(o.prompt_token_ids or []),
                              "completion_tokens": len(c.token_ids)},
                },
                "metadata": {
                    "model": str(model),
                    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "request_latency_ms": round(ms, 2),
                    "retry_count": 0,
                    "method": it.get("method", "POST"),
                    "url": it.get("url", "/v1/chat/completions"),
                },
            })
        print(f"BATCH {start // args.batch_size + 1} requests={len(batch)} ms={ms:.1f}", flush=True)
    print(f"GENERATE_SECONDS: {time.perf_counter() - t_gen:.1f}", flush=True)

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(records, indent=2) + "\n")
    m, _ = analyze.metrics(records)
    print("\n".join(analyze.metric_lines(m)), flush=True)
    print(f"RESULTS_FILE: {out.resolve()}", flush=True)
    print("RESULTS_OK", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
