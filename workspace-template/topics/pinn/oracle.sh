#!/usr/bin/env bash
# topics/pinn/oracle.sh: the scripted correct path, for the lead (not for participants or their agents).
# In a workspace, on a compute node (the Code Server job): submits job.sbatch with `ws-submit --yes`,
# waits with ws-wait, runs analyze.py, fills RESULTS.md from this topic's RESULTS.md.in, and requires
# `ws-check pinn` to report level 3. It proves that the topic is solvable on today's system and that
# the checker recognises a correct solve (the oracle anchor; a fresh workspace is the null anchor, level 0).
#
#   usage: bash topics/pinn/oracle.sh [workspace]      (default: the workspace around $PWD)
#   exit:  0 level 3 reached; 1 anything else (the reason is printed)
set -euo pipefail

TOPIC=pinn
KEYS=(L2_ERROR PDE_RESIDUAL TRAIN_SECONDS)
CHANGED="none: the oracle runs the prepared job.sbatch unchanged."
LIMITATION="One seed, on a problem with a known exact solution; a real PINN problem has none to compare with."

say() { printf 'oracle: %s\n' "$*"; }
fail() { say "FAILED: $*" >&2; exit 1; }

for c in ws-submit ws-wait ws-log ws-check sacct; do
    command -v "$c" >/dev/null 2>&1 || fail "$c is not on PATH (source the kit's env.sh first)"
done

ws=${1:-${WS_HOME:-}}
if [ -z "$ws" ]; then
    d=$PWD
    while [ "$d" != / ] && [ ! -e "$d/.ws-workspace" ]; do d=$(dirname "$d"); done
    [ -e "$d/.ws-workspace" ] || fail "no workspace around $PWD; pass it as the first argument"
    ws=$d
fi
tdir=$ws/topics/$TOPIC
[ -f "$tdir/job.sbatch" ] || fail "$tdir/job.sbatch is missing"
cd "$tdir"
export WS_HOME=$ws

say "submitting $tdir/job.sbatch"
out=$(ws-submit --yes job.sbatch) || { printf '%s\n' "$out"; fail "ws-submit refused or failed"; }
printf '%s\n' "$out"
jobid=$(printf '%s\n' "$out" | grep -oE 'Submitted batch job [0-9]+' | tail -n 1 | grep -oE '[0-9]+$') \
    || fail "no job id in the ws-submit output"

say "waiting for job $jobid"
if ! ws-wait "$jobid" --timeout 1800; then
    ws-log "$jobid" || true
    fail "job $jobid did not complete"
fi

log=$tdir/slurm-$jobid.out
if [ ! -f "$log" ]; then
    log=$(ws-log "$jobid" | sed -n 's/^\[ws\] log: \(.*\) ([0-9]* bytes)$/\1/p' | head -n 1)
fi
[ -n "$log" ] && [ -f "$log" ] || fail "no log for job $jobid"
say "log: $log"

# analyze.py needs matplotlib: the same module as the job. The module scripts are not `set -u` clean.
set +u
module reset && module load pytorch-conda/2.12
set -u
python "$tdir/analyze.py" "$log" --out "$tdir/$TOPIC.png" || fail "analyze.py failed on $log"

# RESULTS.md from the template: the job id, the [ws-env] line and each KEY line copied from the log.
wsenv=$(grep -m 1 '^\[ws-env\]' "$log" || true)
[ -n "$wsenv" ] || fail "the log has no [ws-env] line"
declare -A val=()
for k in "${KEYS[@]}"; do
    val[$k]=$(grep -E "^$k: " "$log" | tail -n 1 | sed -E "s/^$k: *([^ ]+).*/\\1/")
    [ -n "${val[$k]}" ] || fail "the log has no $k: line"
done
verified="sacct: $(sacct -j "$jobid" -X -P -n -o JobID,State,ExitCode,Elapsed,NodeList,Partition,Reservation,AllocTRES | head -n 1); numbers copied from $(basename "$log") by grep; ws-check $TOPIC below."
if [ -f "$ws/RESULTS.md" ]; then
    cp -p "$ws/RESULTS.md" "$ws/RESULTS.md.before-oracle"
    say "kept the previous RESULTS.md as RESULTS.md.before-oracle"
fi
kv=
for k in "${KEYS[@]}"; do kv+="$k=${val[$k]}"$'\n'; done
JOBID=$jobid WSENV=$wsenv KV=$kv CHANGED=$CHANGED VERIFIED=$verified LIMITATION=$LIMITATION awk '
    BEGIN { n = split(ENVIRON["KV"], lines, "\n")
            for (i = 1; i <= n; i++) if (lines[i] != "") { p = index(lines[i], "="); v[substr(lines[i], 1, p - 1)] = substr(lines[i], p + 1) } }
    /^JOBID: </ { print "JOBID: " ENVIRON["JOBID"]; next }
    /^- `\[ws-env\]/ { print "- `" ENVIRON["WSENV"] "`"; next }
    /^- [A-Z][A-Z0-9_]*: </ { k = substr($2, 1, length($2) - 1); if (k in v) { print "- " k ": " v[k]; next } }
    /^<The one change/ { print ENVIRON["CHANGED"]; next }
    /^<The sacct line/ { print ENVIRON["VERIFIED"]; next }
    /^<What this run/ { print ENVIRON["LIMITATION"]; next }
    { print }' "$tdir/RESULTS.md.in" > "$ws/RESULTS.md"
say "wrote $ws/RESULTS.md"

res=$(ws-check "$TOPIC")
printf '%s\n' "$res"
if printf '%s\n' "$res" | grep -q '^LEVEL: 3 '; then
    say "PASS: job $jobid reaches level 3 ($(for k in "${KEYS[@]}"; do printf '%s=%s ' "$k" "${val[$k]}"; done))"
    exit 0
fi
fail "ws-check $TOPIC did not report level 3 for job $jobid"
