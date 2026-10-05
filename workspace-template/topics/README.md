# Topics: choose one

Each topic runs one real job of at most 1 GPU (or 16 CPU cores) for at most 15
minutes, and follows `topics/LOG-PROTOCOL.md`. Read only the chosen topic's
directory.

| # | Topic | What you do | Runs on |
|---|---|---|---|
| 1 | `ml-gpu` | Train a small CNN on FashionMNIST for 2 epochs; report throughput and accuracy. | 1 A40 |
| 2 | `pinn` | Solve the 1-D heat equation with a physics-informed neural network; compare with the exact solution. | 1 A40 |
| 3 | `llm-batch` | Run 40 prompts through a small local LLM with LLMFlux; measure answer rate and latency. | 1 A40 |
| 4 | `compile-parallel` | Compile a C integrator, parallelize it with OpenMP and MPI, and measure the speedup. | 16 CPU cores |
| 5 | `tailor` | Adapt one of topics 1-4 to your field; the scheduler checks stay, the thresholds relax. | as the base topic |

After the chosen topic reaches level 3, the session continues open-ended (M7):
your own goal in `open/`, with `topics/open-ended/` as its guide. It is the
part after the prepared topic, not a choice here.
