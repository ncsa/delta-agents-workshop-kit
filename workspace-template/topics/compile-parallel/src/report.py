#!/usr/bin/env python3
"""Summarise the pi runs of one compile-parallel job: speedups, agreement, RESULTS_OK.

Reads the PROGRAM/RESULT lines that pi_serial, pi_omp and pi_mpi print (job.sbatch collects
them in times.txt) and prints, in log-protocol form:

    SERIAL_TIME: <s>
    SPEEDUP_OMP<t>: <serial time / OMP time with t threads>     one line per thread count
    SPEEDUP_MPI<r>: <serial time / MPI time with r ranks>
    RESULT_SPREAD: <largest minus smallest RESULT>
    RESULT_AGREE: yes|no                                        yes when the spread is <= 1e-9
    RESULTS_OK                                                  only when everything is present and agrees

Exit status 1 when a run is missing or the results disagree, so the job ends FAILED.
System python3 is enough (no module): only the standard library is used.

    python3 src/report.py times.txt
"""
import re
import sys

TOL = 1e-9
PROG_RE = re.compile(r"^PROGRAM:\s*(\S+)")
RES_RE = re.compile(r"^RESULT:\s*([-+0-9.eE]+)\s+TIME:\s*([-+0-9.eE]+)\s+WORKERS:\s*(\d+)")


def parse(path):
    """[(program, result, time, workers)] in file order; a RESULT line belongs to the PROGRAM line before it."""
    runs, prog = [], None
    with open(path, errors="replace") as fh:
        for line in fh:
            line = line.strip()
            m = PROG_RE.match(line)
            if m:
                prog = m.group(1)
                continue
            m = RES_RE.match(line)
            if m:
                runs.append((prog or "unknown", float(m.group(1)), float(m.group(2)), int(m.group(3))))
                prog = None
    return runs


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python3 src/report.py times.txt")
    runs = parse(sys.argv[1])
    serial = [r for r in runs if r[0] == "pi_serial"]
    omp = {r[3]: r for r in runs if r[0] == "pi_omp"}
    mpi = {r[3]: r for r in runs if r[0] == "pi_mpi"}
    problems = []
    if not serial:
        problems.append("no pi_serial run")
    if not omp:
        problems.append("no pi_omp run")
    if not mpi:
        problems.append("no pi_mpi run")
    if serial:
        ts = serial[-1][2]
        print(f"SERIAL_TIME: {ts:.4f}")
        for label, table in (("OMP", omp), ("MPI", mpi)):
            for w in sorted(table):
                t = table[w][2]
                if t > 0:
                    print(f"SPEEDUP_{label}{w}: {ts / t:.2f}")
                else:
                    problems.append(f"{label} time with {w} workers is {t}")
    results = [r[1] for r in runs]
    spread = (max(results) - min(results)) if results else float("nan")
    agree = bool(results) and spread <= TOL
    print(f"RESULT_SPREAD: {spread:.3e}")
    print(f"RESULT_AGREE: {'yes' if agree else 'no'}")
    if not agree:
        problems.append(f"RESULT values differ by {spread:.3e} (more than {TOL:g})")
    if problems:
        print("report: " + "; ".join(problems), file=sys.stderr)
        return 1
    print("RESULTS_OK", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
