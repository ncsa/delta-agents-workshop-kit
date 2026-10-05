# shellcheck shell=bash
# env.sh: source this file to use the workshop kit:  source /work/hdd/<code>/ws-kit/env.sh
# It loads workshop.env from this directory (variables already set in your environment win),
# exports the WS_* variables, puts the kit's bin/ on PATH once, and prepares the shell for the
# agent harness (module load hpc-gpt; opencode's file watcher and self-update off). It prints
# nothing on success, apart from a note on a login node (the agent may run there; a compute-node shell is recommended).
# Bash only; safe to source from shells running with set -u.

if [ -z "${BASH_VERSION:-}" ]; then
    echo "[ws] error: env.sh needs bash; run 'bash' first, then source it again" >&2
    # shellcheck disable=SC2317
    return 1 2>/dev/null || exit 1
fi

_ws_env_main() {
    local dir f n
    local -A keep=()
    dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || return 1
    f=$dir/workshop.env
    if [ -r "$f" ]; then
        for n in $(compgen -v WS_); do keep[$n]=${!n}; done
        # shellcheck disable=SC1090,SC1091
        . "$f"
        for n in "${!keep[@]}"; do printf -v "$n" '%s' "${keep[$n]}"; done
    elif [ -z "${_WS_ENV_WARNED:-}" ]; then
        echo "[ws] warning: no workshop.env beside $dir/env.sh; using built-in defaults (reservations and accounts are not configured)" >&2
        _WS_ENV_WARNED=1
    fi
    if [ -z "${WS_KIT_RO:-}" ]; then WS_KIT_RO=$dir; fi
    for n in $(compgen -v WS_); do export "${n?}"; done
    case ":${PATH:-}:" in
        *":$WS_KIT_RO/bin:"*) ;;
        *) PATH="$WS_KIT_RO/bin${PATH:+:$PATH}"; export PATH ;;
    esac
    # C16: the harness itself starts the agent (hpc-gpt, opencode, ...), so this shell carries what
    # ws-agent used to set: no file watcher, no self-update, the Lustre copy of the LLMFlux containers.
    export OPENCODE_DISABLE_FILEWATCHER=1 OPENCODE_DISABLE_AUTOUPDATE=1
    # opencode keeps its sessions in SQLite (WAL mode), which needs every process on one host; on the
    # NFS home a database last used on another node gives "locking protocol" or a frozen TUI, so keep
    # it on this node's /tmp (the workshop's memory is PROGRESS.md; a value you set yourself wins).
    OPENCODE_DB=${OPENCODE_DB:-${TMPDIR:-/tmp}/opencode-${USER:-$(id -un)}.db}
    export OPENCODE_DB
    if [ -n "${WS_LLMFLUX_CONTAINERS_DIR:-}" ] && [ -d "$WS_LLMFLUX_CONTAINERS_DIR" ]; then
        LLMFLUX_CONTAINERS_DIR=$WS_LLMFLUX_CONTAINERS_DIR
        export LLMFLUX_CONTAINERS_DIR
    elif [ -d "$WS_KIT_RO/containers/2.0.0" ]; then
        LLMFLUX_CONTAINERS_DIR=$WS_KIT_RO/containers/2.0.0
        export LLMFLUX_CONTAINERS_DIR
    fi
    if [ "$(type -t module 2>/dev/null)" = function ] && ! command -v hpc-gpt >/dev/null 2>&1; then
        # "&& n=0 || n=$?": a caller's set -e must not end the shell on a failed load.
        case $- in
            *u*) set +u; module load hpc-gpt >/dev/null 2>&1 && n=0 || n=$?; set -u ;;
            *) module load hpc-gpt >/dev/null 2>&1 && n=0 || n=$? ;;
        esac
        if [ "$n" -ne 0 ] || ! command -v hpc-gpt >/dev/null 2>&1; then
            echo "[ws] warning: module load hpc-gpt did not work; run it yourself before you start the agent" >&2
        fi
    fi
    case $(hostname 2>/dev/null) in
        dt-login*)
            # shellcheck disable=SC1091
            ( . "$WS_KIT_RO/lib/ws-common.sh" && ws_login_note ) 2>/dev/null | sed 's/^/[ws] /' >&2 ;;
    esac
    return 0
}

if _ws_env_main; then _ws_env_rc=0; else _ws_env_rc=1; fi
unset -f _ws_env_main
if [ "$_ws_env_rc" -ne 0 ]; then unset _ws_env_rc; return 1; fi
unset _ws_env_rc
