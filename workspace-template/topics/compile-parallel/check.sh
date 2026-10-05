#!/usr/bin/env bash
# topics/compile-parallel/check.sh: acceptance levels for the compile-parallel topic. Run it as
# `ws-check compile-parallel`, which uses the kit's read-only copy; editing the workspace copy changes
# nothing. Logic: lib/check-common.sh.
set -euo pipefail

CHECK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CK_LIB=${WS_KIT_RO:-}/lib/check-common.sh
if [ -z "${WS_KIT_RO:-}" ] || [ ! -f "$CK_LIB" ]; then CK_LIB=$CHECK_DIR/../../../lib/check-common.sh; fi
# shellcheck source-path=SCRIPTDIR source=../../../lib/check-common.sh
. "$CK_LIB"

CK_TOPIC=compile-parallel
CK_PLOT=scaling.png
CK_SUBMIT_HINT="submit topics/compile-parallel/job.sbatch with ws-submit --cpu"
# A CPU job: WS_PART_CPU and WS_RES_CPU, no GPU, and the 16 cores of the prepared job.sbatch.
CK_KIND=cpu
CK_TRES_REQUIRE=(cpu=16)

# Level-2 threshold 6, calibrated 2026-09-28 (N=1e9, 16 cores); the shipped reference
# (reference/slurm-reference.out) has SPEEDUP_OMP16 11.73. 6 catches "no speedup" with margin.
SPEEDUP_OMP16_MIN=6
SPEEDUP_MPI16_MIN=6
# Every RESULT: value (serial, OpenMP, MPI) must agree within this; correctness, so --tailored keeps it.
RESULT_TOL=1e-9

# Speedups: reported value within 5 %.
ck_metric SPEEDUP_OMP16 ge "$SPEEDUP_OMP16_MIN" rel
ck_metric SPEEDUP_MPI16 ge "$SPEEDUP_MPI16_MIN" rel

# The RESULT: lines of all runs agree within RESULT_TOL, and report.py said so (RESULT_AGREE: yes).
ck_topic_checks() {
    local jid=$1 log=$2 stats n spread agree wsenv cc
    [ -f "$log" ] || return 0
    wsenv=$(ck_wsenv_line "$log")
    cc=$(ck_wsenv_field "$wsenv" cc)
    if [ -n "$cc" ]; then ck_evidence cc "$cc"; fi
    stats=$(awk '/^RESULT:/ { v = $2 + 0; n++; if (n == 1 || v < lo) lo = v; if (n == 1 || v > hi) hi = v }
        END { if (n) printf "%d %.3e\n", n, hi - lo; else print "0 -" }' "$log")
    n=${stats%% *} spread=${stats#* }
    ck_evidence result_lines "$n RESULT: line(s), spread $spread"
    if [ "$n" -lt 2 ]; then
        ck_check 2 result_agree fail "$n RESULT: line(s) in the log; need the serial, OpenMP and MPI runs" \
            "The log of job $jid has $n RESULT: line(s): keep the serial, OpenMP and MPI srun lines of job.sbatch, then resubmit with ws-submit --cpu."
    elif ! ck_cmp "$spread" le "$RESULT_TOL"; then
        ck_check 2 result_agree fail "RESULT: values differ by $spread (more than $RESULT_TOL)" \
            "The RESULT: values of job $jid differ by $spread, more than $RESULT_TOL: one program computes a different sum (a missing reduction, a race, or -ffast-math); fix it before looking at speed."
    else
        ck_check 2 result_agree ok "$n RESULT: values agree within $RESULT_TOL (spread $spread)"
    fi
    agree=$(awk 'index($0, "RESULT_AGREE:") == 1 { v = $2 } END { print v }' "$log")
    if [ "$agree" = yes ]; then
        ck_check 2 result_agree_line ok "RESULT_AGREE: yes"
    else
        ck_check 2 result_agree_line fail "RESULT_AGREE: ${agree:-(missing)}" \
            "The log of job $jid has no \`RESULT_AGREE: yes\` line: keep the python3 src/report.py times.txt line at the end of job.sbatch."
    fi
}

ck_main "$@"
