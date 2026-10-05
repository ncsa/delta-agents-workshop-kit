#!/bin/bash
#SBATCH --job-name=ws-envcheck
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=2g --time=00:02:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit: submit with `ws-submit --cpu envcheck.sbatch`
# About 20 seconds: proves the Cray compiler wrapper and cray-mpich inside a job, on a CPU node.
set -euo pipefail
# The module scripts are not written for `set -u`; relax it for this command only.
set +u
module reset
set -u
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=none module=PrgEnv-gnu cc=$(which cc)"
echo "CC: $(which cc)"
echo "CC_VERSION: $(cc --version 2>&1 | head -n 1)"
echo "CRAYPE: ${CRAYPE_VERSION:-unknown} MPICH: ${CRAY_MPICH_VERSION:-unknown}"
if command -v mpicc >/dev/null 2>&1; then
    echo "MPICC_SHOW: $(mpicc -show 2>&1 | head -n 1)"
else
    echo "MPICC_SHOW: none (cc adds the MPI flags itself)"
fi
echo "NVCC: $(command -v nvcc || echo none)"
echo "SRUN_CPUS: $(srun --ntasks=1 --cpus-per-task=2 nproc)"
echo "RESULTS_OK"
