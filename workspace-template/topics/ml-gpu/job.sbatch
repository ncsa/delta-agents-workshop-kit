#!/bin/bash
#SBATCH --job-name=ws-ml-gpu
#SBATCH --nodes=1 --ntasks-per-node=1 --cpus-per-task=16
#SBATCH --gpus-per-node=1 --mem=48g --time=00:10:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit
set -euo pipefail
# Run from the topic directory whether ws-submit was called there or in the workspace root.
if [ -d topics/ml-gpu ]; then cd topics/ml-gpu; fi
# The module scripts are not written for `set -u`; relax it for these two commands only.
set +u
module reset && module load pytorch-conda/2.12
set -u
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=${gpu:-none} module=pytorch-conda/2.12"
srun python -u src/train.py --data data/FashionMNIST --epochs 2 --batch-size 256 --seed 1234
