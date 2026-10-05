#!/usr/bin/env python3
"""Staff only: fetch the llm-batch models into the kit, once, on a login node (ops/stage-data.sh).

Downloads Qwen/Qwen2.5-1.5B-Instruct (about 3.1 GB) and Qwen/Qwen2.5-7B-Instruct (about 15.2 GB),
both under the Apache-2.0 license and not gated (no HF token), with
huggingface_hub.snapshot_download(local_dir=...) into <dest>/Qwen2.5-1.5B-Instruct and
<dest>/Qwen2.5-7B-Instruct, the paths models.ws.yaml.in names (<dest> = $WS_KIT_RO/models).
(The 3B Instruct model is not Apache-2.0 but under the non-commercial Qwen RESEARCH LICENSE, so the
kit does not stage it.) Only the files vLLM needs are fetched (config, tokenizer, safetensors), plus
LICENSE and any NOTICE: Apache-2.0 section 4(a) asks for the license with every copy.
Each directory is then checked: config.json, tokenizer files and LICENSE present, the safetensors
shards listed in the index present, and the total size within the expected range. An existing
complete directory is kept (snapshot_download skips files it already has). Never used in a
participant job.

    python src/stage_models.py "$WS_KIT_RO/models"              (needs huggingface_hub)
    python src/stage_models.py --check-only "$WS_KIT_RO/models"
exit: 0 every model staged and checked; 1 otherwise.
"""
import argparse
import json
import sys
from pathlib import Path

# repo id -> (directory name, minimum GB, maximum GB) of the safetensors snapshot
MODELS = {
    "Qwen/Qwen2.5-1.5B-Instruct": ("Qwen2.5-1.5B-Instruct", 2.8, 3.6),
    "Qwen/Qwen2.5-7B-Instruct": ("Qwen2.5-7B-Instruct", 14.5, 16.0),
}
PATTERNS = ["*.json", "*.safetensors", "*.txt", "*.model", "tokenizer*", "merges.txt", "vocab.json",
            "LICENSE*", "NOTICE*"]


def check(d, lo, hi):
    """A list of problems with the model directory d (empty when it is complete)."""
    problems = []
    for f in ("config.json", "tokenizer_config.json", "LICENSE"):
        if not (d / f).is_file():
            problems.append(f"{f} missing")
    shards = sorted(d.glob("*.safetensors"))
    index = d / "model.safetensors.index.json"
    if index.is_file():
        wanted = set(json.loads(index.read_text()).get("weight_map", {}).values())
        missing = sorted(w for w in wanted if not (d / w).is_file())
        if missing:
            problems.append(f"shards missing: {', '.join(missing)}")
    elif not shards:
        problems.append("no *.safetensors")
    gb = sum(p.stat().st_size for p in d.rglob("*") if p.is_file() and ".cache" not in p.parts) / 1e9
    if not lo <= gb <= hi:
        problems.append(f"{gb:.2f} GB, expected {lo}-{hi} GB")
    return problems, gb


def main():
    ap = argparse.ArgumentParser(description="Stage the llm-batch models (staff only, login node).")
    ap.add_argument("dest", help="the kit's models directory, e.g. $WS_KIT_RO/models")
    ap.add_argument("--check-only", action="store_true", help="only check what is already there")
    ap.add_argument("--only", choices=sorted(MODELS), help="stage one model")
    args = ap.parse_args()

    dest = Path(args.dest)
    dest.mkdir(parents=True, exist_ok=True)
    ok = True
    for repo, (name, lo, hi) in MODELS.items():
        if args.only and repo != args.only:
            continue
        d = dest / name
        if not args.check_only:
            from huggingface_hub import snapshot_download
            print(f"stage: {repo} -> {d}", flush=True)
            snapshot_download(repo_id=repo, local_dir=str(d), allow_patterns=PATTERNS)
        problems, gb = check(d, lo, hi) if d.is_dir() else (["directory missing"], 0.0)
        if problems:
            ok = False
            print(f"FAIL {name}: {'; '.join(problems)}")
        else:
            print(f"OK   {name}: {gb:.2f} GB in {d}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
