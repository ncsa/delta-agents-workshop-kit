# shellcheck shell=bash
# lib/check-common.sh: the shared acceptance checker behind `ws-check <topic>`.
# Source it from topics/<topic>/check.sh; do not execute it. Design: kit.md §3 (level ladder), §4 (ws-check).
#
# Interface for a topic's check.sh (C3 and C4 topics use the same one):
#
#   CK_TOPIC=ml-gpu                      topic name (required)
#   CK_PLOT=ml-gpu.png                   plot file level 3 needs (default <topic>.png; empty = no plot check)
#   CK_KIND=gpu|cpu                      picks WS_PART_GPU/WS_RES_GPU or WS_PART_CPU/WS_RES_CPU (default gpu)
#   CK_PARTITION, CK_RESERVATION         override the partition/reservation from workshop.env
#   CK_GPUS                              gres/gpu count AllocTRES must show (default WS_GPU_MAX for gpu, 0 = unchecked)
#   CK_GPU_NAME                          substring the [ws-env] gpu= field must contain (default from the partition)
#   CK_TRES_REQUIRE=(cpu=16)             further AllocTRES key=value pairs that must match exactly
#   CK_REQUIRE_WSENV=1                   log must have the [ws-env] line
#   CK_REQUIRE_RESULTS_OK=1              log must have a RESULTS_OK line
#   CK_METRIC_FN=ck_log_value            function "<fn> <jobid> <log> <KEY>" printing a metric's value
#   ck_metric KEY ge|le|present THRESHOLD rel|err|rate [required|optional]
#                                        one evidence metric: threshold (level 2) and tolerance class (level 3);
#                                        rel = 5 % relative, err = 5 % relative or 1e-3 absolute, rate = 1 % relative
#   ck_topic_checks <jobid> <log>        optional hook: add topic-specific checks with ck_check
#   CK_SUBMIT_HINT="..."                 the level-0 hint's next step (default: submit topics/<topic>/job.sbatch)
#   CK_RESULTS_DIRS=(open)               where RESULTS.md may be; a relative entry is under the workspace
#                                        (default: topics/<topic>, the workspace, the job's WorkDir)
#   CK_RESULTS_HINT="... \$jid"          the no-RESULTS.md hint's next step; $jid becomes the job id
#   CK_JOB_SCRIPT_PREFIX=open/           evaluate only jobs whose .ws/jobs.tsv script column starts with it
#   ck_main "$@"                         parse --tailored/--json, evaluate, print; always exits 0
#
#   ck_check <stage 1|2|3> <name> ok|fail|skip <detail> [hint]
#                                        record a check; the first failing check of the lowest failing stage
#                                        gives the hint. Stage 1 = a job ran, 2 = completed with evidence,
#                                        3 = reported and verified.
#   ck_evidence <key> <value>            add an evidence line
#   During evaluation the current job is in CK_JOB, CK_JOB_STATE, CK_JOB_WORKDIR, CK_LOG, CK_RESULTS,
#   CK_WS (workspace) and CK_TAILORED (0/1).
#
# The checker only reads: sacct, scontrol show job, the workspace's .ws/jobs.tsv, logs, RESULTS.md, the plot.

if [ -n "${_CK_COMMON_LOADED:-}" ]; then return 0; fi
_CK_COMMON_LOADED=1

_CK_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=ws-common.sh
. "$_CK_LIB_DIR/ws-common.sh"

# Tolerances (design §3): relative for most metrics, absolute floor for errors, tighter for rates.
CK_TOL_REL=0.05
CK_TOL_ERR_ABS=1e-3
CK_TOL_RATE=0.01

# The sacct fields, in the order the design gives them.
CK_SACCT_FIELDS=JobID,JobName,State,ExitCode,Elapsed,NodeList,Partition,Reservation,AllocTRES,WorkDir

CK_LEVEL_LABELS=("no finished job" "a job ran" "completed with evidence" "verified and reported")

CK_M_KEY=() CK_M_CMP=() CK_M_THR=() CK_M_KIND=() CK_M_REQ=()

# ck_metric KEY CMP THRESHOLD KIND [required|optional]: declare one evidence metric.
ck_metric() {
    CK_M_KEY+=("$1"); CK_M_CMP+=("$2"); CK_M_THR+=("$3"); CK_M_KIND+=("$4"); CK_M_REQ+=("${5:-required}")
}

# ck_isnum <s>: succeed when <s> is a plain decimal or scientific number.
ck_isnum() { [[ ${1-} =~ ^[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?$ ]]; }

# ck_cmp <a> ge|le|gt|lt <b>: numeric comparison (both must be numbers).
ck_cmp() {
    ck_isnum "$1" && ck_isnum "$3" || return 1
    awk -v a="$1" -v op="$2" -v b="$3" 'BEGIN {
        a += 0; b += 0
        if (op == "ge") r = (a >= b); else if (op == "le") r = (a <= b)
        else if (op == "gt") r = (a > b); else if (op == "lt") r = (a < b); else r = 0
        exit !r }'
}

# ck_tolerance <kind> <logvalue>: print the allowed absolute difference for a reported value.
ck_tolerance() {
    awk -v k="$1" -v l="$2" -v rel="$CK_TOL_REL" -v ea="$CK_TOL_ERR_ABS" -v rate="$CK_TOL_RATE" 'BEGIN {
        l += 0; if (l < 0) l = -l
        t = (k == "rate") ? rate * l : rel * l
        if (k == "err" && t < ea + 0) t = ea + 0
        printf "%.6g\n", t }'
}

# ck_matches <reported> <logvalue> <kind>: succeed when the reported value is within tolerance.
ck_matches() {
    ck_isnum "$1" && ck_isnum "$2" || return 1
    awk -v r="$1" -v l="$2" -v t="$(ck_tolerance "$3" "$2")" 'BEGIN {
        d = r - l; if (d < 0) d = -d; al = (l < 0) ? -l : l
        exit !(d <= t + 1e-12 * al + 1e-300) }'
}

# ck_tol_text <kind>: the tolerance in words.
ck_tol_text() {
    case $1 in
        rate) echo "1 %" ;;
        err) echo "5 % or 1e-3 absolute" ;;
        *) echo "5 %" ;;
    esac
}

# _ck_first_number <text>: print the first number in <text> (after optional spaces, backticks, asterisks).
_ck_first_number() {
    local s=$1
    s=${s#"${s%%[![:space:]\`*]*}"}
    if [[ $s =~ ^([-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?) ]]; then printf '%s\n' "${BASH_REMATCH[1]}"; fi
}

# ck_log_value <jobid> <log> <KEY>: the value of the last "KEY: value" line of the log (empty if none).
ck_log_value() {
    local line
    [ -f "$2" ] || return 0
    line=$(awk -v k="$3:" 'index($0, k) == 1 { v = substr($0, length(k) + 1) } END { print v }' "$2")
    _ck_first_number "$line"
}

# ck_log_has_line <log> <text>: succeed when a line of the log is exactly <text> (trailing spaces ignored).
ck_log_has_line() {
    [ -f "$1" ] || return 1
    awk -v t="$2" '{ sub(/[ \t\r]+$/, "") } $0 == t { f = 1; exit } END { exit !f }' "$1"
}

# ck_wsenv_line <log>: the first [ws-env] line of the log.
ck_wsenv_line() {
    [ -f "$1" ] || return 0
    awk 'index($0, "[ws-env]") == 1 { print; exit }' "$1"
}

# ck_wsenv_field <line> <field>: a field of a [ws-env] line; values may contain spaces (gpu=NVIDIA A40).
ck_wsenv_field() {
    local rest
    case " $1" in *" $2="*) ;; *) return 0 ;; esac
    rest=" $1"
    rest=${rest#*" $2="}
    printf '%s\n' "$rest" | sed -E 's/ +[A-Za-z_]+=.*$//; s/[[:space:]]+$//'
}

# ck_results_value <file> <KEY>: the first number after "KEY:" in RESULTS.md (KEY not part of a longer name).
ck_results_value() {
    local line
    [ -f "$1" ] || return 0
    line=$(awk -v k="$2:" '{
        s = $0
        while ((i = index(s, k)) > 0) {
            p = (i > 1) ? substr(s, i - 1, 1) : ""
            if (p !~ /[A-Za-z0-9_@]/) { print substr(s, i + length(k)); exit }
            s = substr(s, i + length(k))
        } }' "$1")
    _ck_first_number "$line"
}

# ck_results_jobid <file>: the job id on the first JOBID: line of RESULTS.md (empty if none).
ck_results_jobid() {
    local line
    [ -f "$1" ] || return 0
    line=$(awk '{ s = $0; i = index(s, "JOBID:"); if (i > 0) { p = (i > 1) ? substr(s, i - 1, 1) : ""
        if (p !~ /[A-Za-z0-9_]/) { print substr(s, i + 6); exit } } }' "$1")
    line=${line#"${line%%[![:space:]\`*]*}"}
    if [[ $line =~ ^([0-9]+(_[0-9]+)?) ]]; then printf '%s\n' "${BASH_REMATCH[1]}"; fi
}

# ck_tres_value <AllocTRES> <key>: the value of one key (gres/gpu, cpu, node, mem) in an AllocTRES string.
ck_tres_value() {
    local IFS=, kv
    for kv in $1; do
        if [ "${kv%%=*}" = "$2" ]; then printf '%s\n' "${kv#*=}"; return 0; fi
    done
}

# ck_is_terminal <state>: succeed for a finished job state (COMPLETED, FAILED, CANCELLED by ..., TIMEOUT ...).
ck_is_terminal() {
    case ${1%% *} in
        COMPLETED|FAILED|CANCELLED|TIMEOUT|OUT_OF_MEMORY|NODE_FAIL|PREEMPTED|BOOT_FAIL|DEADLINE|REVOKED) return 0 ;;
    esac
    return 1
}

# ck_gpu_name_for_partition <partition>: the GPU model a partition name implies (A40, A100, H200), or empty.
ck_gpu_name_for_partition() {
    case $1 in
        gpuA40*) echo A40 ;;
        gpuA100*) echo A100 ;;
        gpuH200*) echo H200 ;;
        gpuMI100*) echo MI100 ;;
    esac
}

# _ck_jobs_tsv_ids: job ids recorded by ws-submit in .ws/jobs.tsv (one per line).
_ck_jobs_tsv_ids() {
    local f=$CK_WS/.ws/jobs.tsv
    [ -f "$f" ] || return 0
    awk -F'\t' '{ if ($1 ~ /^[0-9]+(_[0-9]+)?$/) print $1 }' "$f"
}

# _ck_jobs_tsv_scripts: "<jobid><TAB><script column>" for each job id in .ws/jobs.tsv (its first row).
_ck_jobs_tsv_scripts() {
    local f=$CK_WS/.ws/jobs.tsv
    [ -f "$f" ] || return 0
    awk -F'\t' '$1 ~ /^[0-9]+(_[0-9]+)?$/ && !seen[$1]++ { print $1 "\t" $3 }' "$f"
}

# _ck_jobs_tsv_output <jobid>: the --output of that job's effective sbatch line in .ws/jobs.tsv.
_ck_jobs_tsv_output() {
    local f=$CK_WS/.ws/jobs.tsv eff
    [ -f "$f" ] || return 0
    eff=$(awk -F'\t' -v j="$1" '$1 == j { print $5; exit }' "$f")
    if [[ $eff =~ --output[=\ ]([^ ]+) ]]; then printf '%s\n' "${BASH_REMATCH[1]}"; fi
}

# _ck_in_ws <path>: succeed when <path> is the workspace or below it (logical or physical path).
_ck_in_ws() {
    local p=$1 w
    [ -n "$p" ] || return 1
    for w in "$CK_WS" "$CK_WS_PHYS"; do
        [ -n "$w" ] || continue
        if [ "$p" = "$w" ] || [[ $p == "$w"/* ]]; then return 0; fi
    done
    return 1
}

# ck_find_log <jobid> <workdir> <jobname>: print the job's log path (as ws-log locates it), or nothing.
#   ws_locate_job_log (lib/ws-common.sh, the ws-log search) first; then 1. StdOut= from `scontrol show
#   job`; 2. --output from .ws/jobs.tsv; 3. <workdir>/slurm-<id>.out; 4. <workdir>/logs/<id>.out;
#   5. the same two in the topic directory and the workspace.
ck_find_log() {
    local id=$1 wd=$2 name=${3:-} out c d
    local -a cands=()
    if declare -F ws_locate_job_log >/dev/null && out=$(ws_locate_job_log "$CK_WS" "$id" 2>/dev/null) \
        && [ -r "$out" ]; then
        printf '%s\n' "$out"
        return 0
    fi
    if command -v scontrol >/dev/null 2>&1 \
        && out=$(scontrol show job "$id" 2>/dev/null) \
        && [[ $out =~ StdOut=([^[:space:]]+) ]]; then
        cands+=("${BASH_REMATCH[1]}")
    fi
    out=$(_ck_jobs_tsv_output "$id")
    if [ -n "$out" ]; then
        out=${out//%j/$id}
        out=${out//%A/${id%%_*}}
        out=${out//%x/$name}
        out=${out//%u/${USER:-}}
        case $out in /*) cands+=("$out") ;; *) cands+=("${wd:-$CK_WS}/$out") ;; esac
    fi
    for d in ${wd:+"$wd"} "$CK_WS/topics/$CK_TOPIC" "$CK_WS"; do
        cands+=("$d/slurm-$id.out" "$d/logs/$id.out")
    done
    for c in "${cands[@]}"; do
        if [ -f "$c" ] && [ -r "$c" ]; then printf '%s\n' "$c"; return 0; fi
    done
}

# ck_find_results <jobid> <workdir>: RESULTS.md citing that job, else the first found, in CK_RESULTS_DIRS
# (default: the topic dir, the workspace, the workdir).
ck_find_results() {
    local d first=
    local -a dirs=()
    if declare -p CK_RESULTS_DIRS >/dev/null 2>&1; then
        for d in "${CK_RESULTS_DIRS[@]}"; do
            case $d in /*) dirs+=("$d") ;; *) dirs+=("$CK_WS/$d") ;; esac
        done
    else
        dirs=("$CK_WS/topics/$CK_TOPIC" "$CK_WS" ${2:+"$2"})
    fi
    for d in "${dirs[@]}"; do
        [ -f "$d/RESULTS.md" ] || continue
        if [ "$(ck_results_jobid "$d/RESULTS.md")" = "$1" ]; then printf '%s\n' "$d/RESULTS.md"; return 0; fi
        : "${first:=$d/RESULTS.md}"
    done
    if [ -n "$first" ]; then printf '%s\n' "$first"; fi
}

# ck_find_plot <workdir> <log>: the newest CK_PLOT file in the workdir, log dir, topic dir or workspace.
ck_find_plot() {
    local d best=
    [ -n "$CK_PLOT" ] || return 0
    for d in ${1:+"$1"} ${2:+"$(dirname "$2")"} "$CK_WS/topics/$CK_TOPIC" "$CK_WS"; do
        if [ -f "$d/$CK_PLOT" ]; then
            if [ -z "$best" ] || [ "$d/$CK_PLOT" -nt "$best" ]; then best=$d/$CK_PLOT; fi
        fi
    done
    if [ -n "$best" ]; then printf '%s\n' "$best"; fi
}

# ck_check <stage> <name> <ok|fail|skip> <detail> [hint]: record one check.
ck_check() {
    _ck_c_stage+=("$1"); _ck_c_name+=("$2"); _ck_c_status+=("$3"); _ck_c_detail+=("$4"); _ck_c_hint+=("${5:-}")
}

# ck_evidence <key> <value>: record one evidence line.
ck_evidence() { _ck_e_key+=("$1"); _ck_e_val+=("$2"); }

# ck_notice <text>: record a notice (printed once, never changes the level).
ck_notice() {
    local n
    for n in "${_ck_notices[@]}"; do if [ "$n" = "$1" ]; then return 0; fi; done
    _ck_notices+=("$1")
}

_ck_reset() {
    _ck_c_stage=() _ck_c_name=() _ck_c_status=() _ck_c_detail=() _ck_c_hint=()
    _ck_e_key=() _ck_e_val=()
}

# _ck_compute_level: compute _ck_level and _ck_hint from the recorded checks.
_ck_compute_level() {
    local s i
    _ck_level=3 _ck_hint=
    for s in 1 2 3; do
        for i in "${!_ck_c_stage[@]}"; do
            if [ "${_ck_c_stage[$i]}" = "$s" ] && [ "${_ck_c_status[$i]}" = fail ]; then
                _ck_level=$((s - 1)); _ck_hint=${_ck_c_hint[$i]:-"fix the failing check ${_ck_c_name[$i]}"}
                return 0
            fi
        done
    done
}

# _ck_script_in_prefix <script column>: succeed when the jobs.tsv script column is under
# CK_JOB_SCRIPT_PREFIX ("open/job.sbatch"; an LLMFlux row "llmflux:open" counts as the directory open/).
_ck_script_in_prefix() {
    local s=${1#llmflux:}
    [[ $s/ == "$CK_JOB_SCRIPT_PREFIX"* ]]
}

# _ck_parse_sacct <output>: fill _ck_jobs (sacct rows attributed to this workspace, parent jobs only).
# With CK_JOB_SCRIPT_PREFIX, only the jobs ws-submit recorded with a script under that prefix.
_ck_parse_sacct() {
    local line first=1 i n s
    local -a hdr=() f=()
    local -A tsv=() col=() inpre=()
    _ck_jobs=()
    while IFS= read -r i; do if [ -n "$i" ]; then tsv[$i]=1; fi; done < <(_ck_jobs_tsv_ids)
    if [ -n "${CK_JOB_SCRIPT_PREFIX:-}" ]; then
        while IFS=$'\t' read -r i s; do
            if [ -n "$i" ] && _ck_script_in_prefix "$s"; then inpre[$i]=1; fi
        done < <(_ck_jobs_tsv_scripts)
    fi
    IFS=, read -r -a hdr <<< "$CK_SACCT_FIELDS"
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        IFS='|' read -r -a f <<< "$line"
        if [ "$first" -eq 1 ]; then
            first=0
            if [ "${f[0]:-}" = JobID ]; then hdr=("${f[@]}"); continue; fi
        fi
        col=()
        for n in "${!hdr[@]}"; do col[${hdr[$n]}]=${f[$n]:-}; done
        case ${col[JobID]:-} in ''|*.*) continue ;; esac
        if [ -n "${CK_JOB_SCRIPT_PREFIX:-}" ] && [ -z "${inpre[${col[JobID]%%_*}]:-}" ]; then continue; fi
        if _ck_in_ws "${col[WorkDir]:-}" || [ -n "${tsv[${col[JobID]}]:-}" ]; then
            _ck_jobs+=("${col[JobID]}|${col[JobName]:-}|${col[State]:-}|${col[ExitCode]:-}|${col[Elapsed]:-}|${col[NodeList]:-}|${col[Partition]:-}|${col[Reservation]:-}|${col[AllocTRES]:-}|${col[WorkDir]:-}")
        fi
    done <<< "$1"
}

# ck_magnetic_check <Reservation>: the reservation check with a magnetic reservation (C22, KF1, rule 22):
# the job ran in it, or outside it in the general queue when it was full (or before it started); both
# are fine and say so (C21: agents read "not configured" as "no reservation today"). Another
# reservation's name is not checked.
ck_magnetic_check() {
    local st detail
    IFS=$'\t' read -r st detail < <(ck_magnetic_result "$1")
    ck_check 2 reservation "$st" "$detail"
}

# ck_magnetic_result <Reservation>: "<ok|skip><TAB><detail>" for ck_magnetic_check (and the open-ended
# checker, which replaces its reservation check with it).
ck_magnetic_result() {
    if [ "$1" = "$WS_RES_MAGNETIC" ]; then
        printf 'ok\tReservation=%s (the magnetic workshop reservation)\n' "$1"
    elif [ -z "$1" ]; then
        printf 'ok\tReservation=(none): the job ran outside the magnetic reservation %s, in the general queue (it was full or not started); fine\n' "$WS_RES_MAGNETIC"
    else
        printf 'skip\tReservation=%s, not the magnetic reservation %s; not checked\n' "$1" "$WS_RES_MAGNETIC"
    fi
}

# _ck_eval <row>: evaluate one attributed job; records checks and evidence, sets _ck_level/_ck_hint.
_ck_eval() {
    local jid name state exitc elapsed nodes part resv tres wd
    local v k i thr cmp kind req rep lv ws_line gpu logjob gpus
    IFS='|' read -r jid name state exitc elapsed nodes part resv tres wd <<< "$1"
    _ck_reset
    # shellcheck disable=SC2034  # CK_JOB and CK_JOB_WORKDIR are for ck_topic_checks hooks
    CK_JOB=$jid CK_JOB_STATE=$state CK_JOB_WORKDIR=$wd
    CK_LOG=$(ck_find_log "$jid" "$wd" "$name")
    CK_RESULTS=$(ck_find_results "$jid" "$wd")
    local plot
    plot=$(ck_find_plot "$wd" "$CK_LOG")

    ck_evidence job "$jid ($name)"
    ck_evidence sacct "State=$state ExitCode=$exitc Elapsed=$elapsed NodeList=$nodes Partition=$part Reservation=${resv:-(none)} AllocTRES=${tres:-(none)}"
    ck_evidence workdir "${wd:-(none)}"

    # Stage 1: the job ran (reached a terminal state).
    if ck_is_terminal "$state"; then
        ck_check 1 job_ended ok "job $jid ended $state"
    else
        ck_check 1 job_ended fail "job $jid is ${state:-in an unknown state}" \
            "Job $jid is ${state:-not finished}: wait for it with \`ws-wait $jid\`, then run ws-check $CK_TOPIC again."
    fi

    # Stage 2: the scheduler record.
    if [ "${state%% *}" = COMPLETED ] && [ "$exitc" = 0:0 ]; then
        ck_check 2 completed ok "State=COMPLETED ExitCode=0:0"
    else
        ck_check 2 completed fail "State=$state ExitCode=$exitc" \
            "Job $jid ended ${state%% *} (exit $exitc): read \`ws-log $jid\`, fix the first error line, and resubmit with ws-submit."
    fi
    if [ -z "$CK_PARTITION" ]; then
        ck_check 2 partition skip "no expected partition configured"
    elif [ "$part" = "$CK_PARTITION" ]; then
        ck_check 2 partition ok "Partition=$part"
    else
        ck_check 2 partition fail "Partition=$part, expected $CK_PARTITION" \
            "Job $jid ran on partition ${part:-(none)} instead of $CK_PARTITION: submit it again through ws-submit, which sets the partition."
    fi
    if [ -z "$CK_RESERVATION" ] && [ -n "${WS_RES_MAGNETIC:-}" ]; then
        # C22: the magnetic reservation takes the job when it has room; outside it is fine too.
        ck_magnetic_check "$resv"
    elif [ -z "$CK_RESERVATION" ]; then
        ck_check 2 reservation skip "the workshop reservation is not configured (${_ck_res_var} unset); not checked"
        ck_notice "${_ck_res_var} is not set in workshop.env, so the reservation check was skipped."
    elif [ "$resv" = "$CK_RESERVATION" ]; then
        ck_check 2 reservation ok "Reservation=$resv"
    else
        ck_check 2 reservation fail "Reservation=${resv:-(none)}, expected $CK_RESERVATION" \
            "Job $jid did not run in the reservation $CK_RESERVATION: submit it again through ws-submit, which adds the reservation."
    fi
    if [ "${CK_GPUS:-0}" -gt 0 ]; then
        gpus=$(ck_tres_value "$tres" gres/gpu)
        if [ "${gpus:-0}" = "$CK_GPUS" ]; then
            ck_check 2 gpus ok "AllocTRES gres/gpu=$gpus"
        else
            ck_check 2 gpus fail "AllocTRES gres/gpu=${gpus:-0}, expected $CK_GPUS" \
                "Job $jid had gres/gpu=${gpus:-0} in AllocTRES instead of $CK_GPUS: keep --gpus-per-node=$CK_GPUS in the job script."
        fi
    fi
    for k in "${CK_TRES_REQUIRE[@]}"; do
        v=$(ck_tres_value "$tres" "${k%%=*}")
        if [ "$v" = "${k#*=}" ]; then
            ck_check 2 "tres:${k%%=*}" ok "AllocTRES ${k%%=*}=$v"
        else
            ck_check 2 "tres:${k%%=*}" fail "AllocTRES ${k%%=*}=${v:-(none)}, expected ${k#*=}" \
                "Job $jid had ${k%%=*}=${v:-(none)} in AllocTRES instead of ${k#*=}: keep the resource request of the prepared job script."
        fi
    done

    # Stage 2: the log.
    if [ -n "$CK_LOG" ]; then
        ck_check 2 log_found ok "$CK_LOG"
        ck_evidence log "$CK_LOG"
    else
        ck_check 2 log_found fail "no log found for job $jid" \
            "No log found for job $jid (expected slurm-$jid.out in ${wd:-its submit directory}): run \`ws-log $jid\` to locate it."
        ck_evidence log "(not found)"
    fi
    if [ "$CK_REQUIRE_WSENV" = 1 ]; then
        ws_line=$(ck_wsenv_line "$CK_LOG")
        if [ -n "$ws_line" ]; then
            ck_check 2 ws_env ok "$ws_line"
            ck_evidence ws-env "$ws_line"
            logjob=$(ck_wsenv_field "$ws_line" job)
            if [ -n "$logjob" ] && [ "$logjob" != "$jid" ]; then
                ck_check 2 ws_env_job fail "[ws-env] job=$logjob, but this is job $jid" \
                    "The log found for job $jid says job=$logjob in its [ws-env] line: use the log of the job you are checking."
            fi
            if [ "$CK_KIND" = gpu ]; then
                gpu=$(ck_wsenv_field "$ws_line" gpu)
                if [ -z "$gpu" ] || [ "$gpu" = none ]; then
                    ck_check 2 gpu_seen fail "[ws-env] gpu=${gpu:-(missing)}" \
                        "The [ws-env] line of job $jid shows no GPU: keep --gpus-per-node=1 and the nvidia-smi query in job.sbatch."
                elif [ -n "$CK_GPU_NAME" ] && [[ $gpu != *"$CK_GPU_NAME"* ]]; then
                    ck_check 2 gpu_seen fail "[ws-env] gpu=$gpu, expected an $CK_GPU_NAME" \
                        "The [ws-env] line of job $jid shows gpu=$gpu instead of an $CK_GPU_NAME: submit through ws-submit to $CK_PARTITION."
                else
                    ck_check 2 gpu_seen ok "gpu=$gpu"
                fi
            fi
        elif [ -n "$CK_LOG" ]; then
            ck_check 2 ws_env fail "no [ws-env] line in the log" \
                "The log of job $jid has no [ws-env] line: keep the echo \"[ws-env] ...\" line of the prepared job.sbatch."
        else
            ck_check 2 ws_env fail "no log" "No log found for job $jid: run \`ws-log $jid\` to locate it."
        fi
    fi

    # Stage 2: the evidence metrics and their thresholds (--tailored: present only).
    for i in "${!CK_M_KEY[@]}"; do
        k=${CK_M_KEY[$i]} cmp=${CK_M_CMP[$i]} thr=${CK_M_THR[$i]} kind=${CK_M_KIND[$i]} req=${CK_M_REQ[$i]}
        lv=$("$CK_METRIC_FN" "$jid" "$CK_LOG" "$k" || true)
        _ck_logval[$k]=$lv
        if [ -z "$lv" ]; then
            if [ "$req" = required ]; then
                ck_check 2 "metric:$k" fail "no $k: line in the log" \
                    "The log of job $jid has no \`$k:\` line: the job did not finish its work, so read \`ws-log $jid\`."
            else
                ck_check 2 "metric:$k" skip "no $k: line in the log (optional)"
            fi
            continue
        fi
        ck_evidence "$k" "$lv"
        if [ "$cmp" = present ]; then
            ck_check 2 "metric:$k" ok "$k: $lv (present)"
        elif [ "$CK_TAILORED" = 1 ]; then
            ck_check 2 "metric:$k" ok "$k: $lv (present; tailored, so the threshold $cmp $thr is not applied)"
        elif ck_cmp "$lv" "$cmp" "$thr"; then
            ck_check 2 "metric:$k" ok "$k: $lv ($cmp $thr)"
        else
            local word=below
            if [ "$cmp" = le ]; then word=above; fi
            ck_check 2 "metric:$k" fail "$k: $lv is $word the threshold $thr" \
                "$k is $lv in job $jid, $word the threshold $thr: see topics/$CK_TOPIC/README.md § Pitfalls for the usual cause, fix it and resubmit."
        fi
    done
    if declare -F ck_topic_checks >/dev/null; then ck_topic_checks "$jid" "$CK_LOG"; fi
    if [ "$CK_REQUIRE_RESULTS_OK" = 1 ]; then
        if ck_log_has_line "$CK_LOG" RESULTS_OK; then
            ck_check 2 results_ok ok "RESULTS_OK present"
        else
            ck_check 2 results_ok fail "no RESULTS_OK line" \
                "The log of job $jid has no RESULTS_OK line: the run did not finish, so read the last lines with \`ws-log $jid\`."
        fi
    fi

    # Stage 3: RESULTS.md cites this job and its numbers match the log; the plot is newer than the log.
    if [ -z "$CK_RESULTS" ]; then
        if [ -n "${CK_RESULTS_HINT:-}" ]; then
            ck_check 3 results_md fail "no RESULTS.md" "There is no RESULTS.md yet: ${CK_RESULTS_HINT//\$jid/$jid}."
        else
            ck_check 3 results_md fail "no RESULTS.md" \
                "There is no RESULTS.md yet: write it from topics/$CK_TOPIC/RESULTS.md.in with the numbers of job $jid."
        fi
    else
        ck_check 3 results_md ok "$CK_RESULTS"
        ck_evidence results "$CK_RESULTS"
        rep=$(ck_results_jobid "$CK_RESULTS")
        if [ -z "$rep" ]; then
            ck_check 3 results_jobid fail "RESULTS.md has no JOBID: line" \
                "RESULTS.md has no \`JOBID:\` line: add \`JOBID: $jid\`, the job whose log holds your numbers."
        elif [ "$rep" != "$jid" ]; then
            ck_check 3 results_jobid fail "RESULTS.md cites JOBID $rep, not $jid" \
                "RESULTS.md cites JOBID $rep, but the job that passed level 2 is $jid: report the numbers of job $jid and cite it."
        else
            ck_check 3 results_jobid ok "JOBID: $rep"
        fi
        for i in "${!CK_M_KEY[@]}"; do
            k=${CK_M_KEY[$i]} kind=${CK_M_KIND[$i]} req=${CK_M_REQ[$i]}
            lv=${_ck_logval[$k]:-}
            v=$(ck_results_value "$CK_RESULTS" "$k")
            if [ -z "$v" ]; then
                if [ "$req" = required ]; then
                    ck_check 3 "reported:$k" fail "RESULTS.md has no $k: value" \
                        "RESULTS.md has no \`$k:\` line with a number: copy it from the log of job $jid."
                else
                    ck_check 3 "reported:$k" skip "not reported (optional)"
                fi
                continue
            fi
            ck_evidence "reported $k" "$v"
            if [ -z "$lv" ]; then
                ck_check 3 "reported:$k" fail "RESULTS.md reports $k: $v, the log has none" \
                    "RESULTS.md reports $k: $v, but the log of job $jid has no $k: line: report only numbers the log shows."
            elif ck_matches "$v" "$lv" "$kind"; then
                ck_check 3 "reported:$k" ok "$v matches the log value $lv (tolerance $(ck_tol_text "$kind"))"
            else
                ck_check 3 "reported:$k" fail "$v does not match the log value $lv (tolerance $(ck_tol_text "$kind"))" \
                    "RESULTS.md reports $k: $v, but the log of job $jid has $lv: copy the value from the log."
            fi
        done
    fi
    if [ -n "$CK_PLOT" ]; then
        if [ -z "$plot" ]; then
            ck_check 3 plot fail "no $CK_PLOT" \
                "There is no $CK_PLOT yet: run \`python topics/$CK_TOPIC/analyze.py ${CK_LOG:-slurm-$jid.out}\` to draw it."
        elif [ -n "$CK_LOG" ] && ! [ "$plot" -nt "$CK_LOG" ]; then
            ck_check 3 plot fail "$plot is older than the log" \
                "$CK_PLOT is older than the log of job $jid: rerun \`python topics/$CK_TOPIC/analyze.py $CK_LOG\`."
        else
            ck_check 3 plot ok "$plot (newer than the log)"
            ck_evidence plot "$plot"
        fi
    fi
    _ck_compute_level
}

# _ck_print_text: the human output.
_ck_print_text() {
    local i label=${CK_LEVEL_LABELS[$_ck_level]} st
    if [ "$CK_TAILORED" = 1 ]; then label="$label; tailored"; fi
    printf 'LEVEL: %s (%s)\n' "$_ck_level" "$label"
    printf 'checks:\n'
    for i in "${!_ck_c_name[@]}"; do
        case ${_ck_c_status[$i]} in ok) st=ok ;; fail) st=FAIL ;; *) st=skip ;; esac
        printf '  %-4s %-22s %s\n' "$st" "${_ck_c_name[$i]}" "${_ck_c_detail[$i]}"
    done
    printf 'evidence:\n'
    printf '  %s: %s\n' topic "$CK_TOPIC"
    printf '  %s: %s\n' workspace "$CK_WS"
    for i in "${!_ck_e_key[@]}"; do printf '  %s: %s\n' "${_ck_e_key[$i]}" "${_ck_e_val[$i]}"; done
    for i in "${_ck_notices[@]}"; do printf 'notice: %s\n' "$i"; done
    printf 'hint: %s\n' "$_ck_hint"
}

# _ck_print_json: the same as one JSON object.
_ck_print_json() {
    local i sep=
    printf '{"topic":%s,"tailored":%s,"level":%s,"label":%s,"job":%s,' \
        "$(ws_json_str "$CK_TOPIC")" "$([ "$CK_TAILORED" = 1 ] && echo true || echo false)" "$_ck_level" \
        "$(ws_json_str "${CK_LEVEL_LABELS[$_ck_level]}")" "$(ws_json_str "${_ck_best_id:-}")"
    printf '"workspace":%s,"checks":[' "$(ws_json_str "$CK_WS")"
    for i in "${!_ck_c_name[@]}"; do
        printf '%s{"stage":%s,"name":%s,"status":%s,"detail":%s}' "$sep" "${_ck_c_stage[$i]}" \
            "$(ws_json_str "${_ck_c_name[$i]}")" "$(ws_json_str "${_ck_c_status[$i]}")" "$(ws_json_str "${_ck_c_detail[$i]}")"
        sep=,
    done
    printf '],"evidence":{'
    sep=
    for i in "${!_ck_e_key[@]}"; do
        printf '%s%s:%s' "$sep" "$(ws_json_str "${_ck_e_key[$i]}")" "$(ws_json_str "${_ck_e_val[$i]}")"
        sep=,
    done
    printf '},"jobs":['
    sep=
    for i in "${!_ck_job_levels[@]}"; do
        printf '%s%s' "$sep" "${_ck_job_levels[$i]}"
        sep=,
    done
    printf '],"notices":['
    sep=
    for i in "${_ck_notices[@]}"; do printf '%s%s' "$sep" "$(ws_json_str "$i")"; sep=,; done
    printf '],"hint":%s}\n' "$(ws_json_str "$_ck_hint")"
}

# _ck_internal_error <line>: the ERR trap; one level-0 answer in the requested format, then exit 0.
_ck_internal_error() {
    trap - ERR
    local hint="ws-check hit an internal error near line $1, so tell a helper."
    if [ "${_ck_json:-0}" = 1 ]; then
        printf '{"topic":%s,"level":0,"label":"checker error","checks":[],"evidence":{},"hint":%s}\n' \
            "$(ws_json_str "${CK_TOPIC:-}")" "$(ws_json_str "$hint")"
    else
        printf 'LEVEL: 0 (checker error)\nhint: %s\n' "$hint"
    fi
    exit 0
}

# ck_main [--tailored] [--json]: evaluate every attributed job, report the best one. Always exits 0.
ck_main() {
    local json=0 arg out rc row best_row='' best_level=-1 best_num=-1 num jid
    CK_TAILORED=0
    for arg in "$@"; do
        case $arg in
            --tailored) CK_TAILORED=1 ;;
            --json) json=1 ;;
            -h|--help) echo "usage: ws-check ${CK_TOPIC:-<topic>} [--tailored] [--json]"; exit 0 ;;
            *) ck_notice "ignored unknown argument: $arg" ;;
        esac
    done
    # An internal error still ends with a level and a hint, and exit 0 (errtrace: also inside functions).
    _ck_json=$json
    set -E
    trap '_ck_internal_error "$LINENO"' ERR

    ws_load_env
    : "${USER:=$(id -un 2>/dev/null || echo unknown)}"
    : "${CK_KIND:=gpu}" "${CK_REQUIRE_WSENV:=1}" "${CK_REQUIRE_RESULTS_OK:=1}" "${CK_METRIC_FN:=ck_log_value}"
    : "${CK_PLOT=$CK_TOPIC.png}"
    if ! declare -p CK_TRES_REQUIRE >/dev/null 2>&1; then CK_TRES_REQUIRE=(); fi
    if [ "$CK_KIND" = cpu ]; then
        : "${CK_PARTITION=$WS_PART_CPU}" "${CK_RESERVATION=$WS_RES_CPU}" "${CK_GPUS:=0}"
        _ck_res_var=WS_RES_CPU
    else
        : "${CK_PARTITION=$WS_PART_GPU}" "${CK_RESERVATION=$WS_RES_GPU}" "${CK_GPUS:=$WS_GPU_MAX}"
        _ck_res_var=WS_RES_GPU
    fi
    : "${CK_GPU_NAME=$(ck_gpu_name_for_partition "$CK_PARTITION")}"
    declare -gA _ck_logval=()
    _ck_notices=() _ck_job_levels=() _ck_best_id=
    _ck_reset

    if ! CK_WS=$(ws_find_workspace); then
        CK_WS=
        if [ -e "$HOME/ws-$WS_DATE/.ws-workspace" ]; then CK_WS=$HOME/ws-$WS_DATE; fi
    fi
    if [ -z "$CK_WS" ]; then
        CK_WS="(none)"
        ck_check 1 workspace fail "no workspace found" "No workspace found: run ws-init, then cd into the workspace."
        _ck_compute_level
        if [ "$json" -eq 1 ]; then _ck_print_json; else _ck_print_text; fi
        exit 0
    fi
    CK_WS_PHYS=$(cd "$CK_WS" 2>/dev/null && pwd -P || true)

    if ! command -v sacct >/dev/null 2>&1; then
        out='' rc=127
    elif out=$(sacct -u "$USER" -S today -X -P -o "$CK_SACCT_FIELDS" 2>/dev/null); then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -ne 0 ]; then
        ck_check 1 sacct fail "sacct unavailable (exit $rc)" \
            "sacct is not answering right now, so wait a minute and run ws-check $CK_TOPIC again."
        _ck_compute_level
        if [ "$json" -eq 1 ]; then _ck_print_json; else _ck_print_text; fi
        exit 0
    fi
    _ck_parse_sacct "$out"

    if [ "${#_ck_jobs[@]}" -eq 0 ]; then
        ck_check 1 job_attributed fail "no job from this workspace in sacct today" \
            "No job from this workspace ran today: ${CK_SUBMIT_HINT:-submit topics/$CK_TOPIC/job.sbatch with ws-submit}."
        _ck_compute_level
        if [ "$json" -eq 1 ]; then _ck_print_json; else _ck_print_text; fi
        exit 0
    fi

    # The M3 environment check (job name ws-envcheck) proves the environment, not the topic: it is the
    # best job only when no other job is attributed (CP-k: a passed envcheck read as the M5 result).
    local only_env=1 name
    for row in "${_ck_jobs[@]}"; do
        IFS='|' read -r _ name _ <<< "$row"
        if [ "$name" != ws-envcheck ]; then only_env=0; break; fi
    done

    # Best job: highest level; the newest (largest job id) wins ties.
    for row in "${_ck_jobs[@]}"; do
        _ck_eval "$row"
        jid=${row%%|*}
        num=${jid%%_*}
        _ck_job_levels+=("{\"id\":$(ws_json_str "$jid"),\"state\":$(ws_json_str "$CK_JOB_STATE"),\"level\":$_ck_level}")
        IFS='|' read -r _ name _ <<< "$row"
        if [ "$only_env" -eq 0 ] && [ "$name" = ws-envcheck ]; then continue; fi
        if [ "$_ck_level" -gt "$best_level" ] || { [ "$_ck_level" -eq "$best_level" ] && [ "$num" -gt "$best_num" ]; }; then
            best_level=$_ck_level best_num=$num best_row=$row
        fi
    done
    _ck_eval "$best_row"
    _ck_best_id=${best_row%%|*}
    local ids=() r
    for r in "${_ck_jobs[@]}"; do ids+=("${r%%|*}"); done
    _ck_c_stage=(1 "${_ck_c_stage[@]}") _ck_c_name=(job_attributed "${_ck_c_name[@]}") _ck_c_status=(ok "${_ck_c_status[@]}")
    _ck_c_detail=("${#ids[@]} job(s) from this workspace today: ${ids[*]}; best: $_ck_best_id" "${_ck_c_detail[@]}")
    _ck_c_hint=("" "${_ck_c_hint[@]}")
    if [ "$_ck_level" -eq 3 ] && [ "$CK_TOPIC" = open-ended ]; then
        # C22 (KF13): one M7 checkpoint, then a note per iteration; the next one said as a statement
        _ck_hint="Level 3 reached for job $_ck_best_id: nothing is missing, so record it (ws-progress M7 the first time, ws-progress --note after that), then say the next iteration as a statement."
    elif [ "$_ck_level" -eq 3 ]; then
        _ck_hint="Level 3 reached for job $_ck_best_id: nothing is missing, so record it with ws-progress M6 or try a stretch item in TAILOR.md."
    elif [ "$only_env" -eq 1 ] && [ "${CK_JOB_STATE%% *}" = COMPLETED ]; then
        # Only the environment check ran, and it completed: the next step is the topic's job.
        local next_cmd
        if [ -f "$CK_WS/topics/$CK_TOPIC/job.sbatch" ] && [ "$CK_KIND" = cpu ]; then
            next_cmd="ws-submit --cpu topics/$CK_TOPIC/job.sbatch"
        elif [ -f "$CK_WS/topics/$CK_TOPIC/job.sbatch" ]; then
            next_cmd="ws-submit topics/$CK_TOPIC/job.sbatch"
        else
            next_cmd=${CK_SUBMIT_HINT:-submit topics/$CK_TOPIC/job.sbatch with ws-submit}
        fi
        _ck_hint="environment proven; next: $next_cmd (M4-M5)"
    fi
    if [ "$json" -eq 1 ]; then _ck_print_json; else _ck_print_text; fi
    exit 0
}
