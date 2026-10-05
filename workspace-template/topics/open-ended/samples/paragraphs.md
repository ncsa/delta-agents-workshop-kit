# Sample paragraphs for idea 6

Ten short paragraphs on research computing, written for this workshop. Use them
when you have no text of your own at hand; each paragraph is one record to
summarise.

1. A batch scheduler decides when and where each job runs on a shared cluster.
Users describe what a job needs, such as cores, memory, GPUs and a time limit,
and the scheduler finds a slot that fits. Jobs that ask for less usually start
sooner, because small requests fit into gaps that large ones cannot use. A
realistic time limit is therefore a courtesy to others and an advantage for
yourself.

2. Reproducible results need more than the same code. The software environment,
the input data, the random seeds and the exact command line all shape the
outcome. Recording these next to each result makes it possible to rerun an
experiment months later. A short log line printed by the job itself is often the
most reliable record.

3. Parallel speedup compares the time on one core with the time on many. Perfect
speedup is rare: some work cannot be divided, and threads compete for memory
bandwidth and caches. Pinning threads to cores keeps them from moving around and
often makes timings more stable. Measuring at several thread counts shows where
the gains level off.

4. A GPU runs thousands of simple operations at once, which suits dense linear
algebra and neural networks. Moving data between the host and the GPU costs
time, so small problems may run faster on the CPU. The crossover point depends
on the problem size and the hardware. Timing both for a few sizes is the honest
way to find it.

5. Storage on a cluster usually comes in tiers. A home directory is small and
backed up, a project or work area is large and shared, and node-local scratch is
fast but temporary. Putting each file in the right tier avoids quota surprises
and slow jobs. Large datasets belong in the shared work area, not in the home
directory.

6. Software modules let many versions of a library coexist on one system.
Loading a module adjusts the search paths so that a program finds the right
compiler or Python packages. Resetting the modules before loading new ones
avoids conflicts left over from earlier work. A job script should load its
modules itself rather than rely on the shell it was submitted from.

7. Checkpointing saves the state of a long computation at regular intervals. If
the job is stopped by a time limit or a node failure, it can resume from the
last checkpoint instead of starting over. The interval is a trade-off between
the cost of writing state and the work that could be lost. Testing a restart
early is better than discovering a broken checkpoint at the end.

8. Physics-informed neural networks add the governing equation to the training
loss. The network is rewarded for fitting known data and for satisfying the
equation at sample points inside the domain. This can work with little data, but
training is sensitive to how the loss terms are weighted. Comparing against a
known solution is the usual first check.

9. Large language models can process many prompts in one batch job instead of
answering them one at a time. Batching keeps the GPU busy and lowers the cost
per answer. Structured output, such as JSON with fixed fields, makes the answers
easy to check automatically. A small model is often enough to test the pipeline
before scaling up.

10. Monitoring a running job helps catch problems early. The queue state shows
whether a job is waiting or running, and the job's log shows its progress.
After the job ends, the accounting record reports how long it ran, where, and
how much memory it used. Comparing the request with the actual use helps size
the next job better.
