#!/bin/bash
#SBATCH --job-name=ws-envcheck
#SBATCH --nodes=1 --ntasks-per-node=1 --cpus-per-task=2
#SBATCH --gpus-per-node=1 --mem=8g --time=00:05:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit: submit with `ws-submit envcheck.sbatch`
# About a minute: proves the llmflux module, the LLMFlux container (vLLM, torch, the GPU inside it)
# and the staged model directory, on a GPU node. The first container start can take 1-3 minutes.
set -euo pipefail
if [ -d topics/llm-batch ]; then cd topics/llm-batch; fi
# The module scripts are not written for `set -u`; relax it for these two commands only.
set +u
module reset && module load llmflux
set -u
if [ -n "${WS_LLMFLUX_CONTAINERS_DIR:-}" ] && [ -f "$WS_LLMFLUX_CONTAINERS_DIR/llm_processor.sif" ]; then
    LLMFLUX_CONTAINERS_DIR=$WS_LLMFLUX_CONTAINERS_DIR
fi
sif=$LLMFLUX_CONTAINERS_DIR/llm_processor.sif
model=${MODEL_DIR:-${WS_KIT_RO:?WS_KIT_RO is not set: source the kit env.sh before ws-submit}/models/Qwen2.5-1.5B-Instruct}
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=${gpu:-none} module=llmflux sif=$sif"
echo "LLMFLUX: $(llmflux --version 2>&1 | head -n 1)"
echo "MODEL_STAGED: $([ -f "$model/config.json" ] && echo yes || echo "no ($model/config.json missing)")"
apptainer exec --nv --cleanenv --env "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}" "$sif" python3 -c '
import torch, vllm
print("VLLM:", vllm.__version__)
print("TORCH:", torch.__version__)
print("CUDA_AVAILABLE:", torch.cuda.is_available())
if not torch.cuda.is_available():
    raise SystemExit("no CUDA device inside the container: keep --gpus-per-node=1 and apptainer --nv")
print("GPU_NAME:", torch.cuda.get_device_name(0))
'
echo "RESULTS_OK"
