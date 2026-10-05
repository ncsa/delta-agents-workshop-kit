#!/bin/bash
#SBATCH --job-name=ws-ml-gpu-fallback
#SBATCH --nodes=2 --ntasks-per-node=1 --cpus-per-task=16
#SBATCH --gpus-per-node=1 --mem=48g --time=00:10:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# Stretch (TAILOR.md c), the nccl-fallback lesson from TOOL-083: identical to job.ddp.sbatch except that
# the NCCL network plugin module is unloaded. The job still exits 0 and prints THROUGHPUT, but NCCL
# talks over TCP sockets. Find the "Using network ..." line in both logs and compare.
# Submit with `ws-submit --stretch job.fallback.sbatch`; account, partition and reservation are added by ws-submit.
set -euo pipefail
if [ -d topics/ml-gpu ]; then cd topics/ml-gpu; fi
set +u
module reset && module load pytorch-conda/2.12
# The one difference: pytorch-conda/2.12 loads aws-ofi-nccl automatically; drop it.
module unload aws-ofi-nccl
set -u
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=${gpu:-none} module=pytorch-conda/2.12-no-ofi nodes=$SLURM_JOB_NUM_NODES"
module list 2>&1 | grep -i nccl || echo "no nccl plugin module loaded"

mapfile -t nodes < <(scontrol show hostnames "$SLURM_JOB_NODELIST")
head_ip=$(srun --nodes=1 --ntasks=1 -w "${nodes[0]}" hostname -I | awk '{print $1}')
echo "head node: ${nodes[0]} ($head_ip)"

export NCCL_DEBUG=INFO
srun torchrun --nnodes 2 --nproc_per_node 1 --rdzv_id "$SLURM_JOB_ID" --rdzv_backend c10d \
    --rdzv_endpoint "$head_ip:29500" \
    src/train.py --data data/FashionMNIST --epochs 2 --batch-size 256 --seed 1234
