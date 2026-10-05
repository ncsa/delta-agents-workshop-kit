#!/bin/bash
#SBATCH --job-name=ws-open
#SBATCH --nodes=1 --ntasks-per-node=1 --cpus-per-task=16
#SBATCH --gpus-per-node=1
#SBATCH --mem=48g --time=00:15:00
#SBATCH --output=slurm-%j.out --error=slurm-%j.out
# account, partition and reservation are added by ws-submit.
# GPU job: `ws-submit open/job.sbatch`. CPU job: delete the --gpus-per-node line, use --mem=16g,
# and submit with `ws-submit --cpu open/job.sbatch`.
# Copy this file to open/job.sbatch (M7) and replace every line marked EDIT.
set -euo pipefail
# Run from open/ whether ws-submit was called there or in the workspace root.
if [ -d open ]; then cd open; fi
MODULE="none"                              # EDIT: the module your code needs, e.g. pytorch-conda/2.12
VENV="none"                                # EDIT: .venv if you made open/.venv on top of MODULE
# The module scripts are not written for `set -u`; relax it for these commands only.
set +u
module reset
if [ "$MODULE" != none ]; then module load "$MODULE"; fi
# The venv was made on the session node; the job only activates it.
# shellcheck disable=SC1091
if [ "$VENV" != none ]; then source "$VENV/bin/activate"; fi
set -u
# Plots: matplotlib's svg backend, so no text goes through the Agg canvas, which fails in
# pytorch-conda/2.12 with "FT_Render_Glyph ... raster overflow" (seaborn heatmap and lmplot too).
# Save plots as .svg: a .png still fails.
export MPLBACKEND=svg

# 1. The environment line (topics/LOG-PROTOCOL.md).
gpu=none; if [ -n "${SLURM_JOB_GPUS:-}${CUDA_VISIBLE_DEVICES:-}" ] && g=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null) && [ -n "$g" ]; then gpu=${g%%$'\n'*}; fi
echo "[ws-env] host=$(hostname) job=$SLURM_JOB_ID gpu=$gpu module=$MODULE"

# 2. Your program, launched with srun so Slurm accounts for it. It (or this script) prints one
#    evidence line per result, "KEY: value", for example "RMSE: 0.042" or "EVENTS_PER_S: 1.3e6".
start=$SECONDS
srun --ntasks=1 --cpus-per-task="${SLURM_CPUS_PER_TASK:-1}" echo "EDIT: replace this echo with your program"
echo "ELAPSED_S: $((SECONDS - start))"

# 3. Last line, reached only when everything above succeeded (set -e stops the script on an error).
echo "RESULTS_OK"
