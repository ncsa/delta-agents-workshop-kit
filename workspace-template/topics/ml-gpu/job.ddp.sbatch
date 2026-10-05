#!/bin/bash
#SBATCH --job-name=ws-ml-gpu-ddp
#SBATCH --nodes=2 --ntasks-per-node=1 --cpus-per-task=16
#SBATCH --gpus-per-node=1 --mem=48g --time=00:10:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# Stretch (TAILOR.md b): 2 nodes, 1 GPU each, one torchrun per node. Submit with
# `ws-submit --stretch job.ddp.sbatch`; account, partition and reservation are added by ws-submit.
set -euo pipefail
if [ -d topics/ml-gpu ]; then cd topics/ml-gpu; fi
set +u
module reset && module load pytorch-conda/2.12
set -u
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=${gpu:-none} module=pytorch-conda/2.12 nodes=$SLURM_JOB_NUM_NODES"
module list 2>&1 | grep -i nccl || echo "no nccl plugin module loaded"

# torchrun needs a rendezvous endpoint every node can reach: the first node's address, taken on that node.
mapfile -t nodes < <(scontrol show hostnames "$SLURM_JOB_NODELIST")
head_ip=$(srun --nodes=1 --ntasks=1 -w "${nodes[0]}" hostname -I | awk '{print $1}')
echo "head node: ${nodes[0]} ($head_ip)"

# NCCL_DEBUG=INFO makes the transport visible ("Using network ..."); without it a fallback looks healthy.
export NCCL_DEBUG=INFO
srun torchrun --nnodes 2 --nproc_per_node 1 --rdzv_id "$SLURM_JOB_ID" --rdzv_backend c10d \
    --rdzv_endpoint "$head_ip:29500" \
    src/train.py --data data/FashionMNIST --epochs 2 --batch-size 256 --seed 1234
