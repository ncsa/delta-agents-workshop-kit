#!/usr/bin/env bash
# topics/llm-batch/oracle.sh: the scripted correct path, for the lead (not for participants or their
# agents). In a workspace, on a compute node (the Code Server job): renders models.ws.yaml and submits
# the LLMFlux job with `bash run.sh --yes` (ws-submit --via llmflux), waits with ws-wait, runs analyze.py
# under the llmflux module, fills RESULTS.md from this topic's RESULTS.md.in, and requires
# `ws-check llm-batch` to report level 3. It proves that the topic is solvable on today's system and
# that the checker recognises a correct solve (the oracle anchor; a fresh workspace is the null anchor).
#
#   usage: bash topics/llm-batch/oracle.sh [workspace]      (default: the workspace around $PWD)
#   exit:  0 level 3 reached; 1 anything else (the reason is printed)
set -euo pipefail

TOPIC=llm-batch
KEYS=(ANSWERED JSON_VALID_RATE P50_LATENCY_MS)
CHANGED="none: the oracle runs run.sh unchanged (Qwen2.5-1.5B-Instruct-local, temperature 0, 160 tokens, batch size 8)."
LIMITATION="One model and one run of 40 prompts at temperature 0; the latency includes queueing inside LLMFlux's client batches."

say() { printf 'oracle: %s\n' "$*"; }
fail() { say "FAILED: $*" >&2; exit 1; }

for c in ws-submit ws-wait ws-log ws-check sacct python3; do
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
[ -f "$tdir/run.sh" ] || fail "$tdir/run.sh is missing"
cd "$tdir"
export WS_HOME=$ws

say "submitting the LLMFlux job from $tdir"
out=$(bash run.sh --yes) || { printf '%s\n' "$out"; fail "run.sh (ws-submit --via llmflux) refused or failed"; }
printf '%s\n' "$out"
jobid=$(printf '%s\n' "$out" | grep -oE 'Submitted batch job [0-9]+' | tail -n 1 | grep -oE '[0-9]+$') \
    || fail "no job id in the ws-submit output"

say "waiting for job $jobid"
if ! ws-wait "$jobid" --timeout 1800; then
    ws-log "$jobid" || true
    fail "job $jobid did not complete"
fi

log=$tdir/logs/$jobid.out
if [ ! -f "$log" ]; then
    log=$(ws-log "$jobid" | sed -n 's/^\[ws\] log: \(.*\) ([0-9]* bytes)$/\1/p' | head -n 1)
fi
[ -n "$log" ] && [ -f "$log" ] || fail "no log for job $jobid"
results=$tdir/results/results.json
[ -f "$results" ] || fail "no results file $results"
say "log: $log"
say "results: $results"

# analyze.py needs matplotlib: the llmflux module's Python has it (never load pytorch-conda in the
# same shell). The module scripts are not `set -u` clean.
set +u
module reset && module load llmflux
set -u
python "$tdir/analyze.py" "$results" --out "$tdir/$TOPIC.png" || fail "analyze.py failed on $results"

# RESULTS.md from the template: the job id, the files and each KEY line from analyze.py --metrics.
metrics=$(python3 "$tdir/analyze.py" --metrics "$results") || fail "analyze.py --metrics failed"
declare -A val=()
for k in "${KEYS[@]}"; do
    val[$k]=$(printf '%s\n' "$metrics" | sed -n "s/^$k: *\\([^ ]*\\).*/\\1/p" | tail -n 1)
    [ -n "${val[$k]}" ] || fail "analyze.py printed no $k: line"
done
verified="sacct: $(sacct -j "$jobid" -X -P -n -o JobID,State,ExitCode,Elapsed,NodeList,Partition,Reservation,AllocTRES | head -n 1); numbers from python3 analyze.py --metrics results/results.json; ws-check $TOPIC below."
if [ -f "$ws/RESULTS.md" ]; then
    cp -p "$ws/RESULTS.md" "$ws/RESULTS.md.before-oracle"
    say "kept the previous RESULTS.md as RESULTS.md.before-oracle"
fi
kv=
for k in "${KEYS[@]}"; do kv+="$k=${val[$k]}"$'\n'; done
JOBID=$jobid RESFILE=${results#"$tdir"/} LOGFILE=${log#"$tdir"/} KV=$kv CHANGED=$CHANGED VERIFIED=$verified \
    LIMITATION=$LIMITATION awk '
    BEGIN { n = split(ENVIRON["KV"], lines, "\n")
            for (i = 1; i <= n; i++) if (lines[i] != "") { p = index(lines[i], "="); v[substr(lines[i], 1, p - 1)] = substr(lines[i], p + 1) } }
    /^JOBID: </ { print "JOBID: " ENVIRON["JOBID"]; next }
    /^- results file: </ { print "- results file: " ENVIRON["RESFILE"]; next }
    /^- job log: </ { print "- job log: " ENVIRON["LOGFILE"]; next }
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
