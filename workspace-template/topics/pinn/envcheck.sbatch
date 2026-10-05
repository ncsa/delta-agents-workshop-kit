#!/bin/bash
#SBATCH --job-name=ws-envcheck
#SBATCH --nodes=1 --ntasks-per-node=1 --cpus-per-task=2
#SBATCH --gpus-per-node=1 --mem=8g --time=00:02:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit
# About 30 seconds: proves the module, torch and the GPU inside a job, on the compute node.
set -euo pipefail
# The module scripts are not written for `set -u`; relax it for these two commands only.
set +u
module reset && module load pytorch-conda/2.12
set -u
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
export WS_GPU_NAME=${gpu:-none}
srun python -u -c '
import os, socket
import torch
cuda = torch.cuda.is_available()
job = os.environ.get("SLURM_JOB_ID", "none")
gpu = os.environ.get("WS_GPU_NAME", "none")
print(f"[ws-env] host={socket.gethostname()} job={job} gpu={gpu} module=pytorch-conda/2.12 "
      f"torch={torch.__version__} cuda={cuda}", flush=True)
print("TORCH:", torch.__version__)
print("CUDA_BUILD:", torch.version.cuda)
print("CUDA_AVAILABLE:", cuda)
print("GPU_COUNT:", torch.cuda.device_count())
if not cuda:
    raise SystemExit("no CUDA device visible: keep --gpus-per-node=1 in this script")
print("GPU_NAME:", torch.cuda.get_device_name(0))
x = torch.randn(1024, 1024, device="cuda")
print("MATMUL_OK:", bool(torch.isfinite(x @ x).all()))
print("RESULTS_OK", flush=True)
'
