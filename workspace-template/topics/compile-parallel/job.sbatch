#!/bin/bash
#SBATCH --job-name=ws-compile
#SBATCH --nodes=1 --ntasks=16 --cpus-per-task=1 --mem=16g --time=00:10:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit: submit with `ws-submit --cpu job.sbatch`
set -euo pipefail
# Run from the topic directory whether ws-submit was called there or in the workspace root.
if [ -d topics/compile-parallel ]; then cd topics/compile-parallel; fi
# Intervals of the integral; 1e9 makes the serial run take seconds, so srun's start-up does not dominate.
N=${N:-1000000000}
# The module scripts are not written for `set -u`; relax it for this command only.
set +u
module reset
set -u
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=none module=PrgEnv-gnu cc=$(which cc)"
make -B CC="$(which cc)"
: > times.txt
# --cpus-per-task is not inherited by srun steps: every step says what it needs. For t > 1 srun
# warns "--cpus-per-task value exceeds that of job"; the step still runs, the job holds 16 CPUs.
srun --ntasks=1 --cpus-per-task=1 build/pi_serial "$N" | tee -a times.txt
# The job's cores are spread over the node's NUMA domains: without pinning, threads can share or
# move between cores, and 16 threads reached about half the speedup of 16 MPI ranks (2026-09-28).
export OMP_PROC_BIND=close OMP_PLACES=cores
for t in 1 2 4 8 16; do
    OMP_NUM_THREADS=$t srun --ntasks=1 --cpus-per-task="$t" build/pi_omp "$N"
done | tee -a times.txt
srun --ntasks=16 --cpus-per-task=1 build/pi_mpi "$N" | tee -a times.txt
# prints SPEEDUP_OMP16:, SPEEDUP_MPI16:, RESULT_AGREE: yes and, last, RESULTS_OK
python3 -u src/report.py times.txt
