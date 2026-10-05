#!/bin/bash
#SBATCH --job-name=ws-llm-rawvllm
#SBATCH --nodes=1 --ntasks-per-node=1 --cpus-per-task=16
#SBATCH --gpus-per-node=1 --mem=48g --time=00:15:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit: submit with `ws-submit job.rawvllm.sbatch`
# The raw-vLLM tailor (TAILOR.md): the LLMFlux container, run directly with an offline vLLM script.
# No server, no port, no LLMFlux job generator; the same prompts and the same results-file shape.
set -euo pipefail
if [ -d topics/llm-batch ]; then cd topics/llm-batch; fi
# The module scripts are not written for `set -u`; relax it for these two commands only.
set +u
module reset && module load llmflux
set -u
# The module points LLMFLUX_CONTAINERS_DIR at /sw; use the staged Lustre copy when the kit has one.
if [ -n "${WS_LLMFLUX_CONTAINERS_DIR:-}" ] && [ -f "$WS_LLMFLUX_CONTAINERS_DIR/llm_processor.sif" ]; then
    LLMFLUX_CONTAINERS_DIR=$WS_LLMFLUX_CONTAINERS_DIR
fi
sif=$LLMFLUX_CONTAINERS_DIR/llm_processor.sif
model=${MODEL_DIR:-${WS_KIT_RO:?WS_KIT_RO is not set: source the kit env.sh before ws-submit}/models/Qwen2.5-1.5B-Instruct}
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=${gpu:-none} module=llmflux sif=$sif"
mkdir -p results .cache
# --cleanenv starts the container with an empty environment: pass the GPU and offline caches explicitly.
apptainer exec --nv --cleanenv \
    --bind "$PWD:$PWD" --bind "$model:$model:ro" --pwd "$PWD" \
    --env "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}" \
    --env HF_HUB_OFFLINE=1 --env TRANSFORMERS_OFFLINE=1 --env PYTHONUNBUFFERED=1 \
    --env "HF_HOME=$PWD/.cache/huggingface" --env "XDG_CACHE_HOME=$PWD/.cache" \
    --env "TRITON_CACHE_DIR=$PWD/.cache/triton" \
    "$sif" python3 src/raw_vllm_batch.py --model "$model" --prompts prompts.jsonl --out results/raw.json \
    --max-tokens 160 --temperature 0 --batch-size 8
