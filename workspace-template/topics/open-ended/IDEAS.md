# Ideas for the open-ended part (M7)

The operator edits this list to match the suggestions slide shown at the
room sync before the open-ended part. Each idea starts from a module, needs at most one small
`pip install` into `open/.venv` (on the session node, never in a job), and
finishes in one short job within 1 GPU or 16 cores and 15 minutes. Your own
idea is just as welcome if it fits the same limits (`README.md`).

| # | Idea | Start from | Extra install | Job | Evidence line |
|---|---|---|---|---|---|
| 1 | Fit a scikit-learn model (ridge, then a random forest) to the built-in diabetes dataset and report the test error. | `pytorch-conda/2.12` | `scikit-learn`, if `import sklearn` fails | CPU, 4 cores, 2 min | `RMSE: <value>` for each model |
| 2 | Speed up a pure-Python loop (a pairwise distance sum) with numba and time both versions. | `pytorch-conda/2.12` | none (numba is in the module) | CPU, 16 cores, 5 min | `SPEEDUP: <x>` |
| 3 | Compare a matrix multiply on CPU and GPU with the module's PyTorch, for three sizes. | `pytorch-conda/2.12` | none | 1 A40, 5 min | `GFLOPS_CPU_<n>:`, `GFLOPS_GPU_<n>:` for each size |
| 4 | Download a small public CSV into `open/data` (on the session node), summarise it and draw one plot with seaborn. | `pytorch-conda/2.12` | `seaborn` for the plot (it is not in the module) | CPU, 2 cores, 2 min | `ROWS: <n>`, one `KEY: value` summary |
| 5 | Estimate pi by Monte Carlo in C with OpenMP; compile in the job and time 1 and 16 threads. | the default modules: `module reset` (PrgEnv-gnu, GCC 14) | no venv (README "No venv") | CPU, 16 cores, 3 min | `PI: <value>`, `SPEEDUP_16: <x>` |
| 6 | Summarise ten paragraphs of your own text (paste them or give a path), or `topics/open-ended/samples/paragraphs.md`, with the staged Qwen2.5-1.5B through LLMFlux, as `topics/llm-batch/run.sh` does. | `llmflux` | none | 1 A40, 10 min, `ws-submit --via llmflux` | `ANSWERED: <n>` (analyze.py on results.json; no `[ws-env]`/`RESULTS_OK`) |
| 7 | Integrate the Lorenz system with SciPy for two nearby starting points and measure how fast they separate. | `pytorch-conda/2.12` | `scipy`, if `import scipy` fails | CPU, 2 cores, 2 min | `LYAPUNOV_EST: <value>` |

For each: the scaffold first (`open/README.md`, `open/AGENTS.md` and the
mini-plan in `open/PLAN.md`), then the venv (if any), then `open/job.sbatch`
from `job.template.sbatch`, then `ws-submit`. Heavy frameworks never come from
pip: PyTorch from `pytorch-conda/2.12`; vLLM runs inside LLMFlux's container
(`llmflux`), not as `import vllm`. Copy templates and prepared files with cp,
then edit them; never retype them.
