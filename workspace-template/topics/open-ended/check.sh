#!/usr/bin/env bash
# topics/open-ended/check.sh: the generic checker. Run it as `ws-check open-ended`, which uses the kit's
# read-only copy; editing the workspace copy changes nothing. Logic: lib/check-common.sh.
#
# Level 2: the job COMPLETED on a workshop partition with the matching reservation (the CPU partition
# and WS_RES_CPU, or the GPU partition and WS_RES_GPU) within the caps (at most WS_CPUS_MAX cores,
# at most WS_GPU_MAX GPUs), and its log has [ws-env], at least one `KEY: value` evidence line and
# RESULTS_OK. Level 3: open/RESULTS.md cites that JOBID. No thresholds, so --tailored changes nothing.
# Scope (C21): only jobs ws-submit recorded with a script under open/, and only open/RESULTS.md; the
# prepared topic's jobs and RESULTS.md belong to its own checker.
# An LLMFlux job (idea 6: `ws-submit --via llmflux` run from open/, recorded as llmflux:open) is its own
# case (C22, KF9; README "No venv"): LLMFlux writes its own job script and log, so no [ws-env] and no
# RESULTS_OK are required; the evidence is its results file, read by topics/llm-batch/analyze.py
# --metrics (RECORDS and ANSWERED, at least one answered record). C21: the README said so, the checker
# required both lines, and every LLMFlux idea stopped at level 1.
set -euo pipefail

CHECK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CK_LIB=${WS_KIT_RO:-}/lib/check-common.sh
if [ -z "${WS_KIT_RO:-}" ] || [ ! -f "$CK_LIB" ]; then CK_LIB=$CHECK_DIR/../../../lib/check-common.sh; fi
# shellcheck source-path=SCRIPTDIR source=../../../lib/check-common.sh
. "$CK_LIB"

CK_TOPIC=open-ended
# No plot is required; the job may be a CPU or a GPU job. The CPU checks are the base (no GPU
# requirement, no gpu= in [ws-env]); ck_topic_checks accepts the GPU partition with its reservation.
CK_PLOT=
CK_SUBMIT_HINT="copy topics/open-ended/job.template.sbatch to open/job.sbatch, fill it in, and submit it with ws-submit (add --cpu for a CPU job)"
CK_KIND=cpu
CK_GPUS=0
CK_JOB_SCRIPT_PREFIX=open/
CK_RESULTS_DIRS=(open)   # relative to the workspace
# shellcheck disable=SC2016  # $jid is replaced by check-common.sh with the job id
CK_RESULTS_HINT='write open/RESULTS.md quoting the KEY: value lines and JOBID: $jid'

# Words that look like KEY: value but are messages, not evidence.
OE_NOT_EVIDENCE='^(WARNING|WARN|ERROR|INFO|DEBUG|NOTE|FATAL|CRITICAL|TRACEBACK|USAGE|RESULTS_OK)$'

# _oe_set <check name> <ok|fail|skip> <detail> [hint]: replace the result of a check already recorded.
_oe_set() {
    local i
    for i in "${!_ck_c_name[@]}"; do
        if [ "${_ck_c_name[$i]}" = "$1" ]; then
            _ck_c_status[i]=$2 _ck_c_detail[i]=$3 _ck_c_hint[i]=${4:-}
            return 0
        fi
    done
}

# _oe_drop_notice <prefix>: forget a notice that does not apply to this job.
_oe_drop_notice() {
    local n keep=()
    for n in "${_ck_notices[@]}"; do [[ $n == "$1"* ]] || keep+=("$n"); done
    _ck_notices=("${keep[@]}")
}

# oe_llmflux_dir <jobid>: the directory of an LLMFlux job ("llmflux:<dir>" in .ws/jobs.tsv, relative to
# the workspace); fail for any other job.
oe_llmflux_dir() {
    local row dir
    row=$(ws_job_row "$CK_WS" "$1" 2>/dev/null) || return 1
    dir=$(printf '%s\n' "$row" | cut -f3)
    [[ $dir == llmflux:* ]] || return 1
    dir=${dir#llmflux:}
    case $dir in .) dir=$CK_WS ;; /*) ;; *) dir=$CK_WS/$dir ;; esac
    printf '%s\n' "$dir"
}

# oe_llmflux_results <jobid> <dir>: the job's results file: the --output of its llmflux command (from
# .ws/jobs.tsv, relative to <dir>), else <dir>/results/results.json; nothing when neither exists.
oe_llmflux_results() {
    local eff f
    eff=$(ws_job_row "$CK_WS" "$1" 2>/dev/null | cut -f5) || eff=
    if [[ " $eff " =~ \ --output[=\ ]([^ ]+)\  ]]; then
        f=${BASH_REMATCH[1]}
        case $f in /*) ;; *) f=$2/$f ;; esac
        if [ -f "$f" ]; then printf '%s\n' "$f"; return 0; fi
    fi
    if [ -f "$2/results/results.json" ]; then printf '%s\n' "$2/results/results.json"; fi
}

# oe_llmflux_checks <jobid>: the LLMFlux case: [ws-env] and RESULTS_OK are not required, and the
# evidence is the results file's RECORDS and ANSWERED (analyze.py --metrics, system python3).
oe_llmflux_checks() {
    local jid=$1 dir=$2 f out records answered
    _oe_set ws_env skip "LLMFlux job: its container writes the log, with no [ws-env] line (README, No venv)"
    f=$(oe_llmflux_results "$jid" "$dir")
    if [ -z "$f" ]; then
        ck_check 2 evidence_line fail "no results file for LLMFlux job $jid" \
            "LLMFlux job $jid left no results file (results/results.json in $dir): read \`ws-log $jid\` for the first error, fix it and run open/run.sh again."
        return 0
    fi
    out=$(python3 "$CHECK_DIR/../llm-batch/analyze.py" --metrics "$f" 2>/dev/null) || out=
    records=$(printf '%s\n' "$out" | sed -n 's/^RECORDS: *\([0-9][0-9]*\)$/\1/p')
    answered=$(printf '%s\n' "$out" | sed -n 's/^ANSWERED: *\([0-9][0-9]*\)$/\1/p')
    ck_evidence results_file "$f"
    if [ -n "$answered" ] && [ "$answered" -ge 1 ]; then
        ck_check 2 evidence_line ok "ANSWERED: $answered of RECORDS: ${records:-?} (analyze.py --metrics on $f)"
        ck_evidence evidence_lines "ANSWERED: $answered, RECORDS: ${records:-?}"
    else
        ck_check 2 evidence_line fail "$f has ${records:-no readable} records and ${answered:-no} answered" \
            "The results file of LLMFlux job $jid has no answered record: read \`ws-log $jid\`, fix the first error and run open/run.sh again."
    fi
}

ck_topic_checks() {
    local jid=$1 log=$2 i s part='' resv='' tres='' cpus gpus n first lfdir st detail
    # The LLMFlux case needs no RESULTS_OK (checked after this hook, per job); every other job does.
    CK_REQUIRE_RESULTS_OK=1
    if lfdir=$(oe_llmflux_dir "$jid"); then CK_REQUIRE_RESULTS_OK=0; fi
    for i in "${!_ck_e_key[@]}"; do
        if [ "${_ck_e_key[$i]}" = sacct ]; then s=${_ck_e_val[$i]}; fi
    done
    [[ ${s:-} =~ Partition=([^ ]*)\ Reservation=([^ ]*)\ AllocTRES=([^ ]*) ]] \
        && part=${BASH_REMATCH[1]} resv=${BASH_REMATCH[2]} tres=${BASH_REMATCH[3]}
    if [ "$resv" = "(none)" ]; then resv=; fi
    if [ "$tres" = "(none)" ]; then tres=; fi

    # A GPU job: the GPU partition with the GPU reservation, at most WS_GPU_MAX GPUs.
    if [ -n "$WS_PART_GPU" ] && [ "$part" = "$WS_PART_GPU" ] && [ "$part" != "$WS_PART_CPU" ]; then
        _oe_set partition ok "Partition=$part (the GPU partition)"
        _oe_drop_notice "WS_RES_CPU is not set"
        if [ -z "$WS_RES_GPU" ] && [ -n "${WS_RES_MAGNETIC:-}" ]; then
            # C22: the common check's wording (lib/check-common.sh ck_magnetic_result), in place.
            IFS=$'\t' read -r st detail < <(ck_magnetic_result "$resv")
            _oe_set reservation "$st" "$detail"
        elif [ -z "$WS_RES_GPU" ]; then
            _oe_set reservation skip "the workshop reservation is not configured (WS_RES_GPU unset); not checked"
            ck_notice "WS_RES_GPU is not set in workshop.env, so the reservation check was skipped."
        elif [ "$resv" = "$WS_RES_GPU" ]; then
            _oe_set reservation ok "Reservation=$resv"
        else
            _oe_set reservation fail "Reservation=${resv:-(none)}, expected $WS_RES_GPU" \
                "Job $jid did not run in the reservation $WS_RES_GPU: submit it again through ws-submit, which adds the reservation."
        fi
        gpus=$(ck_tres_value "$tres" gres/gpu)
        if [ "${gpus:-0}" -le "$WS_GPU_MAX" ]; then
            ck_check 2 caps ok "AllocTRES gres/gpu=${gpus:-0} (at most $WS_GPU_MAX)"
        else
            ck_check 2 caps fail "AllocTRES gres/gpu=$gpus, more than $WS_GPU_MAX" \
                "Job $jid used $gpus GPUs: the open-ended caps allow $WS_GPU_MAX; request --gpus-per-node=1."
        fi
    elif [ -n "$part" ] && [ "$part" = "$WS_PART_CPU" ]; then
        cpus=$(ck_tres_value "$tres" cpu)
        if [ "${cpus:-0}" -le "$WS_CPUS_MAX" ]; then
            ck_check 2 caps ok "AllocTRES cpu=${cpus:-0} (at most $WS_CPUS_MAX)"
        else
            ck_check 2 caps fail "AllocTRES cpu=$cpus, more than $WS_CPUS_MAX" \
                "Job $jid used $cpus cores: the open-ended caps allow $WS_CPUS_MAX; ask for fewer tasks or CPUs per task."
        fi
    else
        _oe_set partition fail "Partition=${part:-(none)}, expected $WS_PART_GPU or $WS_PART_CPU" \
            "Job $jid ran on partition ${part:-(none)}: submit through ws-submit (GPU) or ws-submit --cpu (CPU), which set the partition."
    fi

    if [ -n "${lfdir:-}" ]; then
        oe_llmflux_checks "$jid" "$lfdir"
        return 0
    fi

    # At least one evidence line: KEY: value, an upper-case key that is not a log-level word.
    n=0 first=
    if [ -f "$log" ]; then
        while IFS= read -r s; do
            [[ ${s%%:*} =~ $OE_NOT_EVIDENCE ]] && continue
            n=$((n + 1))
            if [ -z "$first" ]; then first=$s; fi
        done < <(grep -E '^[A-Z][A-Z0-9_@]*: *[^ ]' "$log" || true)
    fi
    if [ "$n" -gt 0 ]; then
        ck_check 2 evidence_line ok "$n KEY: value line(s), first: $first"
        ck_evidence evidence_lines "$n (first: $first)"
    else
        ck_check 2 evidence_line fail "no KEY: value evidence line in the log" \
            "The log of job $jid has no evidence line: print one \`KEY: value\` line per result (for example \`RMSE: 0.042\`) before RESULTS_OK, and resubmit."
    fi
}

ck_main "$@"
