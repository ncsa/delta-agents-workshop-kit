# ml-gpu: stretch and tailor

Only after M6 is done (level 3). Every item keeps the caps: 1 GPU per node,
15 minutes, submitted through `ws-submit`. With `ws-check ml-gpu --tailored`
the numeric thresholds relax to "the metric is in the log and matches
RESULTS.md"; the scheduler checks stay.

## a. AMP A/B (two jobs, fits in the session)

`train.py --amp` runs the forward pass under bf16 autocast (the A40 supports bf16).

1. Copy `job.sbatch` to `job.amp.sbatch`; add `--amp` to the `srun python` line.
2. State what you expect and why (faster, slower or the same, and by how much); write it down.
3. `ws-submit job.amp.sbatch`, then with approval `--yes`; `ws-wait`; `ws-log`.
4. Compare `THROUGHPUT:` and `ACCURACY:` of the two jobs; put both job ids
   and both numbers in RESULTS.md under "What changed". This model is small;
   do not be surprised by a small or no speedup, and say so.

## b. 2-node DDP, 1 GPU per node (`ws-submit --stretch`)

`train.py` keeps the distributed branch of the TOOL-083 seed: when `torchrun`
sets `RANK` and `WORLD_SIZE`, it joins a process group (NCCL) and wraps the
model in DistributedDataParallel; each rank trains on its own shard and the
throughput is summed over the ranks.

1. Read `job.ddp.sbatch` together: 2 nodes, `srun torchrun --nnodes 2
   --nproc_per_node 1`, a c10d rendezvous on the first node, `NCCL_DEBUG=INFO`.
2. `ws-submit --stretch job.ddp.sbatch` (dry run), then `--yes` after approval.
3. Evidence: two `[rank r/2] host=...` lines with two different hosts,
   `THROUGHPUT:` (the sum), and the transport line `grep "Using network" slurm-<id>.out`.
   `ws-check ml-gpu` shows `ranks`, `hosts` and `transport` in its evidence block.
4. `ws-check` scores the one-GPU job (the 2-node job has `gres/gpu=2` in total,
   not the `gres/gpu=1` of the acceptance); report the stretch numbers under
   "What changed", citing its job id.

## c. The nccl-fallback lesson: exit 0 is not healthy

`pytorch-conda/2.12` loads the `aws-ofi-nccl` plugin, so NCCL uses the fast
network through libfabric. `job.fallback.sbatch` is `job.ddp.sbatch` with that
plugin unloaded. It still runs, still exits 0 and still prints `THROUGHPUT:`.

1. Submit both (`--stretch`); say which one you expect to be slower, and why.
2. Find the transport line in each log: `grep -n "Using network" slurm-<id>.out`
   (`Libfabric` / `AWS Libfabric` versus `Socket`).
3. Say in one sentence why `COMPLETED` and `RESULTS_OK` did not tell you this.

## Tailor to your field

- Your own small dataset and model, loaded from local files in the workspace
  (no downloads in the job). Keep the evidence lines: `EPOCH n loss acc`,
  `THROUGHPUT:`, `ACCURACY:` (or your metric), `RESULTS_OK`.
- Profile one epoch with `torch.profiler` and read the top-5 kernels table
  (`prof.key_averages().table(sort_by="cuda_time_total", row_limit=5)`).
- Then check with `ws-check ml-gpu --tailored`.
