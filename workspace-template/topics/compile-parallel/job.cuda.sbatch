#!/bin/bash
#SBATCH --job-name=ws-compile-cuda
#SBATCH --nodes=1 --ntasks-per-node=1 --cpus-per-task=16
#SBATCH --gpus-per-node=1 --mem=48g --time=00:05:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit: submit with `ws-submit job.cuda.sbatch` (GPU, no --cpu)
# Stretch (TAILOR.md): runs build/pi_cuda, which the CPU job compiled with `make cuda` (nvcc -arch=sm_86).
set -euo pipefail
if [ -d topics/compile-parallel ]; then cd topics/compile-parallel; fi
N=${N:-1000000000}
if [ ! -x build/pi_cuda ]; then
    echo "build/pi_cuda is missing: add 'make cuda NVCC=\"\$(which nvcc)\"' to job.sbatch after the make line and run that CPU job first" >&2
    exit 1
fi
gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=${gpu:-none} module=none"
srun --ntasks=1 build/pi_cuda "$N"
echo "RESULTS_OK"
