# shellcheck shell=bash disable=SC2034
# (SC2034: the constants below are used by the scripts that source this file.)
# lib/ws-common.sh: shared helpers for the ws-* commands. Source it; do not execute it.
# C2-C6 source this file too: keep function names, constants and output formats stable.
# The file sets no shell options; callers choose their own (the bin/ scripts use set -euo pipefail).

if [ -n "${_WS_COMMON_LOADED:-}" ]; then return 0; fi
_WS_COMMON_LOADED=1

# Exit codes shared by every helper (design §4).
WS_E_OK=0
WS_E_USAGE=1
WS_E_POLICY=2
WS_E_ENV=3
WS_E_SLURM=4
WS_E_JOBFAIL=5

# Directory of this file; the kit root is its parent unless WS_KIT_RO says otherwise.
WS_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

# Module ids and short names, in session order.
WS_MODULES=(M0 M1 M2 M3 M4 M5 M6 M7 M8)
WS_MODULE_NAMES=(launch orient plan env build run analyze open wrap)

# ws_info <msg>: print "[ws] <msg>" on stdout.
ws_info() { printf '[ws] %s\n' "$*"; }

# ws_warn <msg>: print "[ws] warning: <msg>" on stderr.
ws_warn() { printf '[ws] warning: %s\n' "$*" >&2; }

# ws_err <msg>: print "[ws] error: <msg>" on stderr.
ws_err() { printf '[ws] error: %s\n' "$*" >&2; }

# ws_die <code> <msg>: print the error and exit the calling script with <code>.
ws_die() { local code=$1; shift; ws_err "$*"; exit "$code"; }

# Settings a workshop.env fixes: the environment cannot override them (red-team H2: an agent's
# `WS_PART_GPU=gpuA100x4 WS_TIME_MAX=48:00:00 ws-submit ...` must not work). A value the file sets
# wins; a name the file leaves unset keeps the environment's value (then the default).
WS_FILE_WINS=(WS_ACCOUNT_CPU WS_ACCOUNT_GPU WS_PART_CPU WS_PART_GPU WS_RES_CPU WS_RES_GPU WS_RES_MAGNETIC
    WS_GPU_MAX WS_NODES_MAX WS_TIME_MAX WS_MEM_MAX WS_CPUS_MAX WS_OPEN_JOBS_MAX WS_BACKEND_DEFAULT WS_LUMEN_MODELS)

# _ws_source_keep_env <file>: source <file>; WS_* variables already set in the environment win,
# except the WS_FILE_WINS names the file sets.
_ws_source_keep_env() {
    local _ws_f=$1 _ws_n
    local -A _ws_keep=()
    for _ws_n in $(compgen -v WS_); do _ws_keep[$_ws_n]=${!_ws_n}; done
    for _ws_n in "${WS_FILE_WINS[@]}"; do unset "$_ws_n"; done
    # shellcheck disable=SC1090
    . "$_ws_f"
    for _ws_n in "${WS_FILE_WINS[@]}"; do
        if [ -n "${!_ws_n+x}" ]; then unset "_ws_keep[$_ws_n]"; fi
    done
    for _ws_n in "${!_ws_keep[@]}"; do printf -v "$_ws_n" '%s' "${_ws_keep[$_ws_n]}"; done
}

# _ws_defaults: fill schedule and cap defaults (design values); site names stay empty ("not configured").
_ws_defaults() {
    : "${WS_DATE:=2026-10-05}" "${WS_PART_GPU:=gpuA40x4}" "${WS_PART_CPU:=cpu}"
    : "${WS_GPU_MAX:=1}" "${WS_NODES_MAX:=1}" "${WS_TIME_MAX:=00:15:00}" "${WS_MEM_MAX:=60g}" "${WS_CPUS_MAX:=16}"
    # C22 (Q43): open-ended (M7) jobs per workspace, any state
    : "${WS_OPEN_JOBS_MAX:=10}"
    # Operator, Oct 4: the session clock is off by default: ws-status names the module from the
    # PROGRESS.md checkpoints and reports no time box and no pace (the facilitator paces the room).
    # WS_CLOCK=on restores the time boxes below and the ON-TIME/BEHIND/AHEAD pace.
    : "${WS_CLOCK:=off}"
    : "${WS_M0:=10:12}" "${WS_M1:=10:17}" "${WS_M2:=10:23}" "${WS_M3:=10:31}" "${WS_M4:=10:36}"
    : "${WS_M5:=10:42}" "${WS_M6:=10:52}" "${WS_M7:=10:58}" "${WS_M8:=11:38}" "${WS_SESSION_END:=11:45}"
    # C22 (Q41, Q42, L12): glm-5.3 by default; /models offers glm-5.3, glm-5.3-flash, qwen3.8-27b
    : "${WS_MODEL_DEFAULT:=glm-5.3}" "${WS_SMALL_MODEL:=qwen3.8-27b}" "${WS_BACKEND_DEFAULT:=lumen}"
    : "${WS_LUMEN_MODELS:=glm-5.3 glm-5.3-flash qwen3.8-27b}" "${WS_LUMEN_KEY:=auto}"
    : "${WS_CODE:=}" "${WS_ACCOUNT_CPU:=}" "${WS_ACCOUNT_GPU:=}" "${WS_RES_CPU:=}" "${WS_RES_GPU:=}"
    : "${WS_RES_MAGNETIC:=}"
    : "${WS_SHARE:=}" "${WS_REPORTS:=}" "${WS_LUMEN_KEY_FILE:=}" "${WS_STANDBY_DIR:=}" "${WS_FAKE_NOW:=}"
    # WS_SMALL_MODEL is a bare Lumen id since C16; a C15 workshop.env still says lumen-ws/<id>.
    WS_SMALL_MODEL=${WS_SMALL_MODEL#lumen-ws/}
    WS_SMALL_MODEL=${WS_SMALL_MODEL#lumen/}
}

# ws_load_env [file]: load $WS_KIT_RO/workshop.env (environment wins, except for the WS_FILE_WINS
# names the file sets), apply defaults, export WS_*.
ws_load_env() {
    local f n
    if [ -z "${WS_KIT_RO:-}" ]; then WS_KIT_RO=$(dirname "$WS_LIB_DIR"); fi
    f=${1:-$WS_KIT_RO/workshop.env}
    if [ -r "$f" ]; then _ws_source_keep_env "$f"; fi
    if [ -z "${WS_KIT_RO:-}" ]; then WS_KIT_RO=$(dirname "$WS_LIB_DIR"); fi
    _ws_defaults
    for n in $(compgen -v WS_); do
        case $n in WS_E_*|WS_LIB_DIR|WS_MODULES|WS_MODULE_NAMES|WS_STANDBY_MODEL|WS_FILE_WINS) ;; *) export "${n?}" ;; esac
    done
}

# ws_hm_to_min <HH:MM>: print minutes since midnight.
ws_hm_to_min() { local h=${1%%:*} m=${1##*:}; printf '%d\n' $((10#$h * 60 + 10#$m)); }

# ws_now_epoch: print the current epoch seconds, or WS_FAKE_NOW ("HH:MM" today or "YYYY-MM-DD HH:MM").
ws_now_epoch() {
    local f=${WS_FAKE_NOW:-} e
    if [ -n "$f" ]; then
        case $f in
            [0-9]:[0-9][0-9]|[0-9][0-9]:[0-9][0-9]|[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9]*:[0-9][0-9])
                if e=$(date -d "$f" +%s 2>/dev/null); then printf '%s\n' "$e"; return 0; fi ;;
        esac
        ws_warn "WS_FAKE_NOW='$f' is not HH:MM or YYYY-MM-DD HH:MM; using the real clock"
    fi
    date +%s
}

# ws_now_hm: print the current (or fake) local time as HH:MM.
ws_now_hm() { date -d "@$(ws_now_epoch)" +%H:%M; }

# ws_is_login_node: succeed when `hostname` starts with dt-login.
ws_is_login_node() {
    local h
    h=$(hostname 2>/dev/null || true)
    case $h in dt-login*) return 0 ;; esac
    return 1
}

# ws_dur_to_min DURATION: a Slurm duration ([D-]HH:MM[:SS]) in whole minutes; nothing for
# UNLIMITED, INFINITE or an empty value.
ws_dur_to_min() {
    local d=0 rest=${1:-} h m
    case $rest in ''|UNLIMITED|INFINITE) return 0 ;; esac
    case $rest in *-*) d=${rest%%-*}; rest=${rest#*-} ;; esac
    IFS=: read -r h m _ <<< "$rest"
    printf '%d\n' $((10#${d:-0} * 1440 + 10#${h:-0} * 60 + 10#${m:-0}))
}

# res_left <reservation>: print "<seconds> <HH:MM>": the time a job may still run inside the
# reservation (EndTime - now - 1 min, whole minutes: Slurm rounds seconds up) and its end. A
# non-FLEX reservation admits only jobs that end inside it (Q16). Fails when scontrol gives no EndTime.
# ws-submit clamps --time with it; ws_session_srun clamps the session shell.
RES_MARGIN=60     # seconds kept free before the reservation's end
RES_MIN_LEFT=120  # below this, ws-submit refuses: the job could not do anything
res_left() {
    local out end e now left
    out=$(scontrol show reservation "$1" 2>/dev/null) || return 1
    end=$(printf '%s\n' "$out" | tr ' ' '\n' | sed -n 's/^EndTime=//p' | head -n 1)
    [[ $end =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2})?$ ]] || return 1
    e=$(date -d "${end/T/ }" +%s 2>/dev/null) || return 1
    now=$(ws_now_epoch)
    left=$(( (e - now - RES_MARGIN) / 60 * 60 ))
    if [ "$left" -lt 0 ]; then left=0; fi
    printf '%s %s\n' "$left" "$(date -d "@$e" +%H:%M)"
}

# ws_res_window <reservation>: print "<State>|<start>|<end>", start and end as "Mon 09:00" (empty
# when scontrol gives none). Fails, printing nothing, when scontrol cannot show it (not created yet,
# no scontrol here, the controller down). ws-status and ws-preflight show WS_RES_MAGNETIC with it.
ws_res_window() {
    local out st t f=() k
    [ -n "${1:-}" ] && command -v scontrol >/dev/null 2>&1 || return 1
    out=$(timeout 30 scontrol show reservation "$1" 2>/dev/null) || return 1
    [[ $out == *ReservationName=* ]] || return 1
    st=$(printf '%s\n' "$out" | tr ' ' '\n' | sed -n 's/^State=//p' | head -n 1)
    for k in StartTime EndTime; do
        t=$(printf '%s\n' "$out" | tr ' ' '\n' | sed -n "s/^$k=//p" | head -n 1)
        if [[ $t =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} ]]; then
            t=$(LC_ALL=C date -d "${t/T/ }" '+%a %H:%M' 2>/dev/null) || t=
        else
            t=
        fi
        f+=("$t")
    done
    printf '%s|%s|%s\n' "${st:-UNKNOWN}" "${f[0]}" "${f[1]}"
}

# Seconds the session shell ends before the CPU reservation does (a relaunch late in the morning).
WS_SESSION_RES_MARGIN=300

# ws_session_srun: the srun line that opens a compute-node shell for the session: the CPU account
# and partition, the reservation when one is set, 2 CPUs, 4 GB, and WS_SESSION_TIME (01:45:00)
# capped by the partition's MaxTime when scontrol can tell, and by the reservation: when
# WS_RES_CPU has an EndTime, the shell ends 5 minutes before it (EndTime - now - 5 min, rounded down
# to whole minutes, printed as HH:MM:00; at least one minute). Without an EndTime only the first two apply.
ws_session_srun() {
    local t=${WS_SESSION_TIME:-01:45:00} max mt mx rl s
    max=$(scontrol show partition "${WS_PART_CPU:-cpu}" 2>/dev/null | grep -oE 'MaxTime=[^ ]+' | head -n 1 | cut -d= -f2) || max=
    mt=$(ws_dur_to_min "$t"); mx=$(ws_dur_to_min "$max")
    if [ -n "$mx" ] && [ -n "$mt" ] && [ "$mx" -lt "$mt" ]; then t=$max; mt=$mx; fi
    if [ -n "${WS_RES_CPU:-}" ] && [ -n "$mt" ] && rl=$(res_left "$WS_RES_CPU"); then
        # res_left keeps RES_MARGIN free and whole minutes; add it back to get EndTime - now.
        s=$(( (${rl%% *} + RES_MARGIN - WS_SESSION_RES_MARGIN) / 60 ))
        if [ "$s" -lt 1 ]; then s=1; fi
        if [ "$s" -lt "$mt" ]; then t=$(printf '%02d:%02d:00' $((s / 60)) $((s % 60))); fi
    fi
    printf 'srun --account=%s --partition=%s%s --cpus-per-task=2 --mem=4g --time=%s --pty bash\n' \
        "${WS_ACCOUNT_CPU:-}" "${WS_PART_CPU:-cpu}" "${WS_RES_CPU:+ --reservation=$WS_RES_CPU}" "$t"
}

# ws_login_note: what env.sh, ws-init, ws-status and ws-agent say on a login node. The agent may run
# here (its work goes into jobs); a compute-node shell is recommended for the session.
ws_login_note() {
    printf '%s\n' "$(hostname 2>/dev/null || echo this) is a login node, shared by everyone on Delta. The agent can run here" \
        "and submits its work as jobs, but a compute-node shell is recommended for the session:" \
        "  $(ws_session_srun)"
}

# ws_find_workspace: print the workspace root ($WS_HOME, else the nearest parent of $PWD with .ws-workspace); fail if none.
ws_find_workspace() {
    local d
    if [ -n "${WS_HOME:-}" ]; then
        if [ -d "$WS_HOME" ]; then printf '%s\n' "$WS_HOME"; return 0; fi
        return 1
    fi
    d=${PWD:-$(pwd)}
    while :; do
        if [ -e "$d/.ws-workspace" ]; then printf '%s\n' "$d"; return 0; fi
        if [ "$d" = / ] || [ -z "$d" ]; then return 1; fi
        d=$(dirname "$d")
    done
}

# ws_is_module <id>: succeed when <id> is one of M0..M8.
ws_is_module() { case ${1:-} in M[0-8]) return 0 ;; esac; return 1; }

# ws_module_name <M0..M8>: print the module's short name (launch, orient, ...).
ws_module_name() { ws_is_module "$1" || return 1; printf '%s\n' "${WS_MODULE_NAMES[${1#M}]}"; }

# ws_module_box <M0..M8>: print "<start> <end>" (HH:MM) of the module's time box.
ws_module_box() {
    local i start end
    ws_is_module "$1" || return 1
    i=${1#M}
    start="WS_M$i"
    if [ "$i" -eq 8 ]; then end=WS_SESSION_END; else end="WS_M$((i + 1))"; fi
    printf '%s %s\n' "${!start}" "${!end}"
}

# ws_module_for_time [HH:MM]: print the module for the clock (M0 before WS_M1, DONE from WS_SESSION_END).
ws_module_for_time() {
    local now i v mod=M0
    now=$(ws_hm_to_min "${1:-$(ws_now_hm)}")
    if [ "$now" -ge "$(ws_hm_to_min "$WS_SESSION_END")" ]; then printf 'DONE\n'; return 0; fi
    for i in 1 2 3 4 5 6 7 8; do
        v="WS_M$i"
        if [ "$now" -ge "$(ws_hm_to_min "${!v}")" ]; then mod=M$i; fi
    done
    printf '%s\n' "$mod"
}

# ws_json_str <string>: print the string as a quoted JSON string.
ws_json_str() {
    local s=${1-} out='' c i
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    if [[ $s == *[$'\001'-$'\037']* ]]; then
        for ((i = 0; i < ${#s}; i++)); do
            c=${s:i:1}
            if [[ $c == [$'\001'-$'\037'] ]]; then printf -v c '\\u%04x' "'$c"; fi
            out+=$c
        done
        s=$out
    fi
    printf '"%s"\n' "$s"
}

# ws_require_cmd <cmd>...: succeed if every command is on PATH; otherwise print an error and return WS_E_ENV.
ws_require_cmd() {
    local c rc=0
    for c in "$@"; do
        if ! command -v "$c" >/dev/null 2>&1; then ws_err "required command not found: $c"; rc=$WS_E_ENV; fi
    done
    return "$rc"
}

# ws_sha256 <file>: print the file's sha256 hex digest.
ws_sha256() { sha256sum "$1" | cut -d' ' -f1; }

# ws_progress_field <PROGRESS.md> <field>: print a header field's value ("topic: x" -> x); empty if absent.
ws_progress_field() {
    [ -f "$1" ] || return 0
    awk -v k="$2" '/^## /{exit} index($0, k ":") == 1 {v = substr($0, length(k) + 2); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); print v; exit}' "$1"
}

# ws_plan_approval <PLAN.md>: print the value of the plan's approval line ("approved: netid 10:41" ->
# "netid 10:41"); fail when the file or a non-empty value is missing. A template placeholder
# ("<participant> <HH:MM>") is not an approval. C17: the approved plan gates ws-submit --yes.
ws_plan_approval() {
    [ -f "$1" ] || return 1
    awk 'index($0, "approved:") == 1 { v = substr($0, 10); gsub(/^[ \t]+|[ \t\r]+$/, "", v)
        if (v != "" && substr(v, 1, 1) != "<") { print v; f = 1; exit } } END { exit f ? 0 : 1 }' "$1"
}

# ws_plan_approval_state <PLAN.md>: why ws_plan_approval passes or fails, as one word (C22, KF7: one
# refusal for every cause made a weaker model rewrite PLAN.md for 80 minutes): ok, nofile, missing (no
# line starts with "approved:"), indented (only a " approved:" with leading blanks), empty (the line
# has no value) or placeholder (the template's "<...>").
ws_plan_approval_state() {
    if [ ! -f "$1" ]; then echo nofile; return 0; fi
    if ws_plan_approval "$1" >/dev/null; then echo ok; return 0; fi
    awk 'index($0, "approved:") == 1 { v = substr($0, 10); gsub(/^[ \t]+|[ \t\r]+$/, "", v)
            s = (v == "") ? "empty" : "placeholder"; if (!best || s == "placeholder") best = s; next }
         /^[ \t]+approved:/ { ind = 1 }
         END { if (best) print best; else if (ind) print "indented"; else print "missing" }' "$1"
}

# ws_open_jobs <workspace>: the open-ended (M7) job ids ws-submit recorded in .ws/jobs.tsv, one per
# line, in any state: a script under open/, or an LLMFlux run from open/ ("llmflux:open..."). C22 (Q43):
# ws-submit refuses the WS_OPEN_JOBS_MAX+1th, ws-status counts them.
ws_open_jobs() {
    local tsv=$1/.ws/jobs.tsv
    [ -f "$tsv" ] || return 0
    awk -F'\t' 'NR > 1 && $1 ~ /^[0-9]+(_[0-9]+)?$/ && ($3 ~ /^open\// || $3 == "llmflux:open" || $3 ~ /^llmflux:open\//) \
        && !seen[$1]++ { print $1 }' "$tsv"
}

# Model id of the self-hosted standby backend (provider/model in opencode.json).
WS_STANDBY_MODEL=standby/ws-model

# ws_backend_check: succeed when WS_BACKEND_DEFAULT is lumen, standby or split; otherwise print a
# one-line error and return WS_E_ENV.
ws_backend_check() {
    case ${WS_BACKEND_DEFAULT:-} in lumen|standby|split) return 0 ;; esac
    ws_err "WS_BACKEND_DEFAULT='${WS_BACKEND_DEFAULT:-}' in workshop.env is not lumen, standby or split; ask the workshop lead"
    return "$WS_E_ENV"
}

# ws_backend_split <netid>: the split rule. The first field of `printf '%s' <netid> | cksum` (POSIX
# CRC, no trailing newline): even -> lumen, odd -> standby. Stable for a NetID across runs and nodes.
ws_backend_split() {
    local c
    c=$(printf '%s' "$1" | cksum) || return 1
    c=${c%% *}
    if [ $((c % 2)) -eq 0 ]; then echo lumen; else echo standby; fi
}

# ws_backend_assign <netid>: the backend WS_BACKEND_DEFAULT gives this participant (lumen or standby);
# fails (after ws_backend_check's message) for an invalid setting.
ws_backend_assign() {
    ws_backend_check || return
    case $WS_BACKEND_DEFAULT in
        split) ws_backend_split "$1" ;;
        *) echo "$WS_BACKEND_DEFAULT" ;;
    esac
}

# ws_backend_models <lumen|standby>: print "<model> <small_model>" for the backend.
ws_backend_models() {
    case $1 in
        standby) printf '%s %s\n' "$WS_STANDBY_MODEL" "$WS_STANDBY_MODEL" ;;
        *) printf '%s %s\n' "lumen/$WS_MODEL_DEFAULT" "lumen/$WS_SMALL_MODEL" ;;
    esac
}

# ── Lumen (C16): the site provider id "lumen" for every Lumen model, whatever the key ──────────
# Key modes (WS_LUMEN_KEY): site (the NCSA key the hpc-gpt module ships; no apiKey rendered),
# personal (~/.config/lumen/key), workshop (WS_LUMEN_KEY_FILE), auto (personal if that file exists,
# else workshop if WS_LUMEN_KEY_FILE holds a real key, else site).

# Caps table: id, context, output, note (tab-separated).
WS_LUMEN_CAPS=$WS_LIB_DIR/lumen-models.tsv
WS_LUMEN_URL_DEFAULT=https://lumen.ncsa.illinois.edu/v1

# ws_lumen_caps <id>: print "<context> <output>" from lib/lumen-models.tsv; fail when it has no row.
ws_lumen_caps() {
    [ -r "$WS_LUMEN_CAPS" ] || return 1
    awk -F'\t' -v id="$1" '!/^#/ && $1 == id && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ { print $2, $3; f = 1; exit }
        END { exit f ? 0 : 1 }' "$WS_LUMEN_CAPS"
}

# ws_lumen_listed <id>: succeed when <id> is one of WS_LUMEN_MODELS.
ws_lumen_listed() {
    local m
    for m in $WS_LUMEN_MODELS; do [ "$m" = "$1" ] && return 0; done
    return 1
}

# ws_lumen_models_check: WS_LUMEN_MODELS is non-empty, every id has a caps row, and it holds
# WS_MODEL_DEFAULT and WS_SMALL_MODEL; otherwise one error line and WS_E_ENV.
ws_lumen_models_check() {
    local m v
    local -a nocaps=()
    if [ -z "${WS_LUMEN_MODELS//[[:space:]]/}" ]; then
        ws_err "WS_LUMEN_MODELS is empty in workshop.env; ask the workshop lead"
        return "$WS_E_ENV"
    fi
    for m in $WS_LUMEN_MODELS; do
        case $m in *[!A-Za-z0-9._-]*) ws_err "WS_LUMEN_MODELS has '$m', which is not a plain model id; ask the workshop lead"; return "$WS_E_ENV" ;; esac
        ws_lumen_caps "$m" >/dev/null || nocaps+=("$m")
    done
    if [ "${#nocaps[@]}" -gt 0 ]; then
        ws_err "WS_LUMEN_MODELS lists ${nocaps[*]} without a row in lib/lumen-models.tsv; ask the workshop lead"
        return "$WS_E_ENV"
    fi
    for v in WS_MODEL_DEFAULT WS_SMALL_MODEL; do
        if ! ws_lumen_listed "${!v}"; then
            ws_err "$v='${!v}' is not in WS_LUMEN_MODELS ($WS_LUMEN_MODELS); ask the workshop lead"
            return "$WS_E_ENV"
        fi
    done
}

# ws_lumen_personal_key: the participant's own Lumen key file.
ws_lumen_personal_key() { printf '%s\n' "$HOME/.config/lumen/key"; }

# ws_lumen_key_is_real <file>: the file is readable, not empty, and not the publish placeholder.
ws_lumen_key_is_real() {
    [ -n "${1:-}" ] && [ -f "$1" ] && [ -r "$1" ] && [ -s "$1" ] && [ "$(head -c 14 -- "$1")" != ws-placeholder ]
}

# ws_lumen_key_placeholder <file>: the file is the placeholder publish-ro-copy.sh writes.
ws_lumen_key_placeholder() { [ -n "${1:-}" ] && [ -r "$1" ] && [ "$(head -c 14 -- "$1")" = ws-placeholder ]; }

# ws_lumen_key_mode [mode]: resolve <mode> (default $WS_LUMEN_KEY, auto) to site, personal or
# workshop and print it. One error line and WS_E_ENV for an unknown mode, a key file that is
# missing (opencode refuses to start on a {file:} it cannot read), or a personal key others can read.
ws_lumen_key_mode() {
    local m=${1:-${WS_LUMEN_KEY:-auto}} p perm
    p=$(ws_lumen_personal_key)
    case $m in
        auto)
            if [ -e "$p" ]; then m=personal
            elif ws_lumen_key_is_real "$WS_LUMEN_KEY_FILE"; then m=workshop
            else m=site; fi ;;
        site|personal|workshop) ;;
        *) ws_err "Lumen key mode '$m' is not auto, site, personal or workshop"; return "$WS_E_ENV" ;;
    esac
    case $m in
        personal)
            if [ ! -f "$p" ] || [ ! -r "$p" ] || [ ! -s "$p" ]; then
                ws_err "no personal Lumen key in ~/.config/lumen/key (missing, empty or unreadable); put your key there, or use: ws-init --lumen-key site"
                return "$WS_E_ENV"
            fi
            perm=$(stat -L -c %a -- "$p" 2>/dev/null) || perm=777
            if [ $((8#$perm & 8#077)) -ne 0 ]; then
                ws_err "your Lumen key ~/.config/lumen/key is open to group or others (mode $perm); run: chmod 600 ~/.config/lumen/key"
                return "$WS_E_ENV"
            fi ;;
        workshop)
            if [ -z "$WS_LUMEN_KEY_FILE" ] || [ ! -r "$WS_LUMEN_KEY_FILE" ]; then
                ws_err "Lumen key mode workshop, but the workshop key file ${WS_LUMEN_KEY_FILE:-(WS_LUMEN_KEY_FILE is not set)} is not readable; ask the workshop lead"
                return "$WS_E_ENV"
            fi ;;
    esac
    printf '%s\n' "$m"
}

# ws_lumen_key_saved <workspace>: the file where ws-init --lumen-key keeps the participant's choice.
ws_lumen_key_saved() { printf '%s\n' "$1/.ws/lumen-key"; }

# ws_lumen_key_choice <workspace|''>: print "<mode> <source>" before validation, in this order: the
# workspace's saved choice (source saved), else WS_LUMEN_KEY when it is not auto (setting), else
# auto (auto). An invalid saved value is one warning naming the file, then the next rule applies.
# An empty or missing workspace (pre-flight before ws-init) has no saved choice.
ws_lumen_key_choice() {
    local f v
    if [ -n "${1:-}" ]; then
        f=$(ws_lumen_key_saved "$1")
        if [ -f "$f" ]; then
            v=$(head -n 1 -- "$f" 2>/dev/null || true)
            v=${v//[[:space:]]/}
            case $v in
                site|personal|workshop|auto) printf '%s saved\n' "$v"; return 0 ;;
                *) ws_warn "$f says '$v', not auto, site, personal or workshop; ignoring it (rerun ws-init --lumen-key <mode>)" ;;
            esac
        fi
    fi
    case ${WS_LUMEN_KEY:-auto} in
        auto) printf 'auto auto\n' ;;
        *) printf '%s setting\n' "$WS_LUMEN_KEY" ;;
    esac
}

# ws_lumen_key_resolve <workspace|''>: print "<mode> <source>" with <mode> resolved and checked by
# ws_lumen_key_mode (site, personal or workshop) and <source> saved, setting or auto. The one key
# resolution of ws-init, ws-preflight check 7, ws-models and ws-standby status; fails (after
# ws_lumen_key_mode's one error line) when the chosen key cannot be used.
ws_lumen_key_resolve() {
    local c m
    c=$(ws_lumen_key_choice "${1:-}")
    m=$(ws_lumen_key_mode "${c%% *}") || return
    printf '%s %s\n' "$m" "${c#* }"
}

# ws_lumen_key_file <site|personal|workshop>: the file whose key that mode sends (for the site mode,
# the key the hpc-gpt site config names).
ws_lumen_key_file() {
    case $1 in
        personal) ws_lumen_personal_key ;;
        workshop) printf '%s\n' "$WS_LUMEN_KEY_FILE" ;;
        *) printf '%s\n' "${WS_LUMEN_SITE_KEY_FILE:-/path/to/site-lumen-key}" ;;
    esac
}

# ws_lumen_describe <mode>: one phrase for a key mode (never the key).
ws_lumen_describe() {
    case $1 in
        site) echo "site (the NCSA Lumen key the hpc-gpt module ships)" ;;
        personal) echo "personal (~/.config/lumen/key)" ;;
        workshop) echo "workshop (the workshop project key)" ;;
        *) echo "$1" ;;
    esac
}

# ws_lumen_apikey_member <mode>: ', "apiKey": "{file:<key file>}"' for personal and workshop; nothing
# for site (the site config's key applies).
ws_lumen_apikey_member() {
    case $1 in
        personal|workshop) printf ', "apiKey": %s\n' "$(ws_json_str "{file:$(ws_lumen_key_file "$1")}")" ;;
    esac
}

# ws_lumen_options_json <mode>: the provider.lumen "options" members for a key mode, on one line.
ws_lumen_options_json() {
    printf '"baseURL": %s%s\n' "$(ws_json_str "$WS_LUMEN_URL_DEFAULT")" "$(ws_lumen_apikey_member "$1")"
}

# ws_lumen_whitelist_json [ids...]: the ids (default WS_LUMEN_MODELS) as a one-line JSON array body.
ws_lumen_whitelist_json() {
    local s='' m
    if [ $# -eq 0 ]; then set -- $WS_LUMEN_MODELS; fi
    for m in "$@"; do s+="${s:+, }$(ws_json_str "$m")"; done
    printf '%s\n' "$s"
}

# ws_lumen_models_json <indent> [ids...]: one provider.lumen.models entry per id (default
# WS_LUMEN_MODELS) with the caps table's limits, one per line, comma-separated. An id without a row
# gets 131072/16384 (ws_lumen_models_check refuses that case for WS_LUMEN_MODELS).
ws_lumen_models_json() {
    local ind=$1 m c o n=0
    shift
    if [ $# -eq 0 ]; then set -- $WS_LUMEN_MODELS; fi
    for m in "$@"; do
        read -r c o < <(ws_lumen_caps "$m" || echo "131072 16384")
        n=$((n + 1))
        printf '%s%s: { "name": %s, "limit": { "context": %s, "output": %s } }%s\n' "$ind" \
            "$(ws_json_str "$m")" "$(ws_json_str "$m (Lumen)")" "$c" "$o" "$([ "$n" -lt $# ] && echo ,)"
    done
}

# ws_with_hpcgpt <cmd>...: run <cmd> with the hpc-gpt module loaded (Lmod's shell function when this
# shell has it, else a login bash defines it); exit 97 when the load fails.
ws_with_hpcgpt() {
    if [ "$(type -t module 2>/dev/null)" = function ]; then
        (
            set +u
            module load hpc-gpt >/dev/null 2>&1 || exit 97
            set -u
            "$@"
        )
    else
        bash -lc 'module load hpc-gpt >/dev/null 2>&1 || exit 97; exec "$@"' ws-hpcgpt "$@"
    fi
}

# ws_probe_classify <rc> <stdout-file> <stderr-file> <word>: classify one `opencode run` probe
# whose prompt asks for <word>: ok, timeout, no-access, not-found, auth, or "error: <first line>".
# The first line is cut to 160 characters and anything shaped like a key is masked.
ws_probe_classify() {
    local rc=$1 out=$2 err=$3 word=$4 txt first
    txt=$(cat "$out" "$err" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    if [ "$rc" -eq 0 ] && sed 's/\x1b\[[0-9;]*m//g' "$out" 2>/dev/null \
        | WS_W=$word awk 'BEGIN { w = tolower(ENVIRON["WS_W"]) } index(tolower($0), "reply with") == 0 {
            n = split(tolower($0), t, /[^a-z0-9]+/); for (i = 1; i <= n; i++) if (t[i] == w) f = 1 } END { exit f ? 0 : 1 }'; then
        echo ok; return 0
    fi
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then echo timeout; return 0; fi
    if [ "$rc" -eq 127 ]; then echo "error: opencode is not on PATH (module load hpc-gpt)"; return 0; fi
    if grep -qi 'no access to this model' <<<"$txt"; then echo no-access; return 0; fi
    if grep -i 'not found' <<<"$txt" | grep -qvi 'command not found'; then echo not-found; return 0; fi
    if grep -qiE 'invalid (or inactive )?api key|invalid key|unauthori[sz]ed|authentication|(^|[^0-9])401([^0-9]|$)' <<<"$txt"; then
        echo auth; return 0
    fi
    first=$(grep -m 1 -iE 'error|fail|refused|timed? ?out' <<<"$txt" || true)
    if [ -z "$first" ]; then first=$(grep -m 1 -v '^[[:space:]]*$' <<<"$txt" || true); fi
    if [ -z "$first" ] && [ "$rc" -eq 0 ]; then first="empty reply"; fi
    first=$(printf '%s' "${first:-exit $rc, no output}" | sed -E 's/(sk-|Bearer +)[A-Za-z0-9._~+\/=-]+/\1***/g; s/^[[:space:]]+//' | cut -c1-160)
    printf 'error: %s\n' "$first"
}

# ws_oc_set_models <model> <small_model>: filter opencode.json (JSONC) from stdin to stdout, setting
# every "model": line (top level, agent.workshop, command.report, ...) and the "small_model": line.
# Line-oriented, so comments survive; ws-init and ws-standby share it so both write the same bytes.
ws_oc_set_models() {
    local m s
    m=$(printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g')
    s=$(printf '%s' "$2" | sed -e 's/[\\|&]/\\&/g')
    sed -E -e 's|^([[:space:]]*"model"[[:space:]]*:[[:space:]]*")[^"]*(")|\1'"$m"'\2|' \
        -e 's|^([[:space:]]*"small_model"[[:space:]]*:[[:space:]]*")[^"]*(")|\1'"$s"'\2|'
}

# ws_inherited_slurm_vars: print the names of exported SLURM_*, SBATCH_*, SRUN_*, SALLOC_* variables.
# Inside a job (Code Server, srun --pty) these describe the parent allocation.
ws_inherited_slurm_vars() {
    local v
    for v in $(compgen -e); do
        case $v in SLURM_*|SBATCH_*|SRUN_*|SALLOC_*) printf '%s\n' "$v" ;; esac
    done
}

# ws_run_scrubbed <cmd> [args...]: run a command with every SLURM_*, SBATCH_*, SRUN_*, SALLOC_*
# variable unset. sbatch from inside a job otherwise hands the parent's variables to the child,
# whose srun then dies ("SLURM_MEM_PER_CPU, SLURM_MEM_PER_GPU, and SLURM_MEM_PER_NODE are mutually
# exclusive"); knowledge-base/patterns/sbatch-inside-job-inherited-slurm-env-delta.md.
ws_run_scrubbed() {
    (
        for _ws_v in $(compgen -e); do
            case $_ws_v in SLURM_*|SBATCH_*|SRUN_*|SALLOC_*) unset "$_ws_v" ;; esac
        done
        exec "$@"
    )
}

# ws_job_row <workspace> <jobid>: print the job's submission row from .ws/jobs.tsv (the first row
# with that id: jobid, HH:MM, script, topic, effective); fail when the workspace never submitted it.
ws_job_row() {
    local f=$1/.ws/jobs.tsv
    [ -f "$f" ] || return 1
    awk -F'\t' -v id="$2" 'NR > 1 && $1 == id { print; found = 1; exit } END { exit found ? 0 : 1 }' "$f"
}

# _ws_expand_log_pattern <pattern> <jobid> <jobname>: expand %j %J %A %u %x %% in a Slurm file name.
_ws_expand_log_pattern() {
    local p=$1
    p=${p//%%/$'\001'}
    p=${p//%j/$2}; p=${p//%J/$2}; p=${p//%A/$2}
    p=${p//%u/${USER:-}}; p=${p//%x/$3}
    printf '%s\n' "${p//$'\001'/%}"
}

# ws_locate_job_log <workspace> <jobid>: print the path of the job's stdout log; fail when none exists.
# Order: `scontrol show job` StdOut=; the jobs.tsv row's --output (relative to the script's directory,
# or the directory of an "llmflux:<dir>" row); then slurm-<id>.out and then logs/<id>.out, each in the
# script's directory, $PWD and the workspace root.
ws_locate_job_log() {
    local ws=$1 id=$2 out row script dir eff pat name d c
    local -a cands=() dirs=()
    out=$(scontrol show job "$id" 2>/dev/null | tr ' ' '\n' | sed -n 's/^StdOut=//p' | head -n 1) || out=
    if [ -n "$out" ]; then cands+=("$out"); fi
    if row=$(ws_job_row "$ws" "$id"); then
        script=$(printf '%s\n' "$row" | cut -f3)
        eff=$(printf '%s\n' "$row" | cut -f5)
        case $script in
            llmflux:*) dir=${script#llmflux:}; pat= ;;
            *)
                dir=$(dirname "$script")
                pat=$(printf '%s\n' "$eff" | grep -oE -- '--output=[^ ]+' | tail -n 1) || pat=
                pat=${pat#--output=}
                ;;
        esac
        case $dir in /*) ;; .) dir=$ws ;; *) dir=$ws/$dir ;; esac
        if [ -n "$pat" ]; then
            name=$(printf '%s\n' "$eff" | grep -oE -- '--job-name=[^ ]+' | tail -n 1) || name=
            name=${name#--job-name=}
            if [ -z "$name" ]; then name=$(basename "$script"); fi
            pat=$(_ws_expand_log_pattern "$pat" "$id" "$name")
            case $pat in /*) cands+=("$pat") ;; *) cands+=("$dir/$pat") ;; esac
        fi
        dirs+=("$dir")
    fi
    dirs+=("${PWD:-$(pwd)}" "$ws")
    for d in "${dirs[@]}"; do cands+=("$d/slurm-$id.out"); done
    for d in "${dirs[@]}"; do cands+=("$d/logs/$id.out"); done
    for c in "${cands[@]}"; do
        if [ -f "$c" ]; then printf '%s\n' "$c"; return 0; fi
    done
    return 1
}

# ws_progress_add_job <PROGRESS.md> <line>: append <line> ("- <jobid> ...") at the end of "## Jobs"
# (created when missing), rewriting the file in place so its inode and mode stay (like ws-progress).
# A job id "## Jobs" already lists is not added again (a hand-written or repeated line); a
# cancellation line is compared with the cancellation lines only, so it still follows the submission.
ws_progress_add_job() {
    local prog=$1 tmp
    [ -f "$prog" ] || return 1
    tmp=$(mktemp "$prog.XXXXXX") || return 1
    WS_L=$2 awk '
        function flush() { while (blank > 0) { print ""; blank-- } }
        # jobkey(s): the job id of a "- <id> ..." line ("- job <id>", backticks and a colon allowed),
        # plus " cancelled" for a cancellation line; empty when the line names no job id.
        function jobkey(s,   w, n, id) {
            n = split(s, w, /[ \t]+/)
            if (w[1] != "-") return ""
            id = w[2]; if (tolower(id) == "job" && n > 2) id = w[3]
            gsub(/[`*:,]/, "", id)
            if (id !~ /^[0-9]+(_[0-9]+)?$/) return ""
            return id (s ~ /[ \t]cancelled([ \t]|$)/ ? " cancelled" : "")
        }
        BEGIN { line = ENVIRON["WS_L"]; key = jobkey(line) }
        /^## / {
            if (in_jobs && !done) { print line; done = 1 }
            flush()
            in_jobs = ($0 ~ /^## Jobs[ \t]*$/); seen = seen || in_jobs
            print; next
        }
        in_jobs && /^[ \t]*$/ { blank++; next }
        in_jobs && key != "" && jobkey($0) == key { done = 1 }
        { flush(); print }
        END {
            if (in_jobs && !done) { print line; done = 1 }
            flush()
            if (!seen) { print ""; print "## Jobs"; print line }
        }' "$prog" > "$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" > "$prog"
    rm -f "$tmp"
}

# ws_progress_checked <PROGRESS.md> <M0..M8>: succeed when ## Checkpoints has a "- [x] ... <module>" line.
ws_progress_checked() {
    [ -f "$1" ] || return 1
    awk -v m="$2" '
        /^## / { in_cp = ($0 ~ /^## Checkpoints[ \t]*$/); next }
        in_cp && $0 ~ ("^- \\[[xX]\\] ([0-9]+:[0-9][0-9] )?" m "([ \t]|$)") { found = 1; exit }
        END { exit found ? 0 : 1 }' "$1"
}

# ws_progress_checked_hm <PROGRESS.md> <M0..M8>: print the HH:MM of the module's last "- [x] HH:MM
# <module>" checkpoint (nothing when that line has no time); fail when the module is not checked.
ws_progress_checked_hm() {
    [ -f "$1" ] || return 1
    awk -v m="$2" '
        /^## / { in_cp = ($0 ~ /^## Checkpoints[ \t]*$/); next }
        in_cp && $0 ~ ("^- \\[[xX]\\] ([0-9]+:[0-9][0-9] )?" m "([ \t]|$)") {
            found = 1; hm = ($3 ~ /^[0-9]+:[0-9][0-9]$/) ? $3 : "" }
        END { if (found) print hm; exit found ? 0 : 1 }' "$1"
}
