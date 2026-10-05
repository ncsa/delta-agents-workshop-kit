#!/usr/bin/env bash
# topics/llm-batch/check.sh: acceptance levels for the llm-batch topic. Run it as `ws-check llm-batch`,
# which uses the kit's read-only copy; editing the workspace copy changes nothing. Logic: lib/check-common.sh.
#
# LLMFlux writes its own job script and log, so this topic's evidence is the results file, not log
# lines: no [ws-env] or RESULTS_OK is required, and each metric is computed from the results file by
# the kit's analyze.py --metrics (system python3). The results file of a job is, in this order: the
# `RESULTS_FILE:` line of its log (the raw-vLLM tailor prints one); the --output of the llmflux command
# ws-submit recorded in .ws/jobs.tsv; results/results.json in the job's directory; the newest
# data/output/*.json there.
set -euo pipefail

CHECK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CK_LIB=${WS_KIT_RO:-}/lib/check-common.sh
if [ -z "${WS_KIT_RO:-}" ] || [ ! -f "$CK_LIB" ]; then CK_LIB=$CHECK_DIR/../../../lib/check-common.sh; fi
# shellcheck source-path=SCRIPTDIR source=../../../lib/check-common.sh
. "$CK_LIB"

CK_TOPIC=llm-batch
CK_PLOT=llm-batch.png
# How this topic submits (the level-0 hint): LLMFlux writes and submits the job itself.
CK_SUBMIT_HINT="in topics/llm-batch run bash run.sh (a dry run), then bash run.sh --yes"
CK_REQUIRE_WSENV=0
CK_REQUIRE_RESULTS_OK=0
CK_METRIC_FN=llm_metric

# Level-2 thresholds, calibrated 2026-09-28 on one A40 (job 22511402: 40 of 40 answered, JSON_VALID_RATE 1.0,
# P50_LATENCY_MS 313.6 with Qwen2.5-1.5B at temperature 0).
RECORDS_EXPECTED=40
ANSWERED_MIN=38

# Every reported metric must match analyze.py within 1 % (the rate tolerance).
ck_metric ANSWERED ge "$ANSWERED_MIN" rate
ck_metric JSON_VALID_RATE present - rate
ck_metric P50_LATENCY_MS present - rate

# llm_results_file <jobid> <log>: the path of the job's results file (see the header), or nothing.
llm_results_file() {
    local jid=$1 log=$2 wd=${CK_JOB_WORKDIR:-} f row dir eff out
    if [ -f "$log" ]; then
        f=$(awk 'index($0, "RESULTS_FILE:") == 1 { v = substr($0, 14) } END { gsub(/^[ \t]+|[ \t\r]+$/, "", v); print v }' "$log")
        if [ -n "$f" ]; then
            case $f in /*) ;; *) f=$(dirname "$log")/$f ;; esac
            if [ -f "$f" ]; then printf '%s\n' "$f"; return 0; fi
        fi
    fi
    if row=$(ws_job_row "$CK_WS" "$jid" 2>/dev/null); then
        dir=$(printf '%s\n' "$row" | cut -f3)
        eff=$(printf '%s\n' "$row" | cut -f5)
        if [[ $dir == llmflux:* ]] && [[ " $eff " =~ \ --output[=\ ]([^ ]+)\  ]]; then
            out=${BASH_REMATCH[1]}
            dir=${dir#llmflux:}
            case $dir in .) dir=$CK_WS ;; /*) ;; *) dir=$CK_WS/$dir ;; esac
            case $out in /*) f=$out ;; *) f=$dir/$out ;; esac
            if [ -f "$f" ]; then printf '%s\n' "$f"; return 0; fi
        fi
    fi
    for dir in ${wd:+"$wd"} "$CK_WS/topics/$CK_TOPIC"; do
        if [ -f "$dir/results/results.json" ]; then printf '%s\n' "$dir/results/results.json"; return 0; fi
        f=$(ls -t "$dir"/data/output/*.json 2>/dev/null | head -n 1 || true)
        if [ -n "$f" ]; then printf '%s\n' "$f"; return 0; fi
    done
}

# llm_metric <jobid> <log> <KEY>: the KEY value analyze.py --metrics computes from the results file.
llm_metric() {
    local f out line v
    f=$(llm_results_file "$1" "$2")
    [ -n "$f" ] || return 0
    out=$(python3 "$CHECK_DIR/analyze.py" --metrics "$f" 2>/dev/null) || return 0
    while IFS= read -r line; do
        if [[ $line == "$3:"* ]]; then
            v=${line#"$3:"}
            v=${v#"${v%%[![:space:]]*}"}
            if ck_isnum "$v"; then printf '%s\n' "$v"; fi
            return 0
        fi
    done <<< "$out"
}

# _llm_move_last_check_first: put the check just recorded ahead of the metric checks, so its hint
# (about the results file itself) is the one shown when it fails.
_llm_move_last_check_first() {
    local last=$((${#_ck_c_name[@]} - 1)) i first=-1 a
    for i in "${!_ck_c_name[@]}"; do
        if [[ ${_ck_c_name[$i]} == metric:* ]]; then first=$i; break; fi
    done
    [ "$first" -ge 0 ] && [ "$first" -lt "$last" ] || return 0
    for a in _ck_c_stage _ck_c_name _ck_c_status _ck_c_detail _ck_c_hint; do
        local -n arr=$a
        arr=("${arr[@]:0:$first}" "${arr[$last]}" "${arr[@]:$first:$((last - first))}")
        unset -n arr
    done
}

# The results file exists, is readable and has the 40 records (--tailored: at least one record);
# the container log's "Server ready" and "Processed N items" lines are evidence only.
ck_topic_checks() {
    local jid=$1 log=$2 f n want=$RECORDS_EXPECTED line
    f=$(llm_results_file "$jid" "$log")
    if [ -z "$f" ]; then
        ck_check 2 results_file fail "no results file for job $jid" \
            "Job $jid left no results file (results/results.json in ${CK_JOB_WORKDIR:-the topic directory}): read \`ws-log $jid\` for the first error, fix it and run run.sh again."
        _llm_move_last_check_first
        return 0
    fi
    ck_evidence results_file "$f"
    n=$(llm_metric "$jid" "$log" RECORDS)
    if [ -z "$n" ]; then
        ck_check 2 results_file fail "$f is not a readable results file" \
            "$f is not a JSON list of records: it was cut short or edited, so rerun the job with run.sh."
        _llm_move_last_check_first
        return 0
    fi
    ck_evidence records "$n"
    if [ "$CK_TAILORED" = 1 ]; then want=1; fi
    if { [ "$CK_TAILORED" = 1 ] && [ "$n" -ge 1 ]; } || [ "$n" -eq "$want" ]; then
        ck_check 2 results_file ok "$f: $n records"
    else
        ck_check 2 results_file fail "$f has $n records, expected $want" \
            "The results file of job $jid has $n records instead of $want: run all of prompts.jsonl (src/make_prompts.py regenerates it) with run.sh."
        _llm_move_last_check_first
    fi
    if [ -f "$log" ]; then
        if grep -q 'Server ready' "$log"; then ck_evidence server "Server ready (container log)"; fi
        line=$(grep -oE 'Processed [0-9]+ items' "$log" | tail -n 1 || true)
        if [ -n "$line" ]; then ck_evidence processed "$line"; fi
    fi
}

ck_main "$@"
