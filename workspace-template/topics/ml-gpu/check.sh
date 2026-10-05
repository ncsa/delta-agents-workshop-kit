#!/usr/bin/env bash
# topics/ml-gpu/check.sh: acceptance levels for the ml-gpu topic. Run it as `ws-check ml-gpu`, which uses
# the kit's read-only copy; editing the workspace copy changes nothing. Logic: lib/check-common.sh.
set -euo pipefail

CHECK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CK_LIB=${WS_KIT_RO:-}/lib/check-common.sh
if [ -z "${WS_KIT_RO:-}" ] || [ ! -f "$CK_LIB" ]; then CK_LIB=$CHECK_DIR/../../../lib/check-common.sh; fi
# shellcheck source-path=SCRIPTDIR source=../../../lib/check-common.sh
. "$CK_LIB"

CK_TOPIC=ml-gpu
CK_PLOT=ml-gpu.png

# Level-2 thresholds, calibrated 2026-09-27 on one A40 (job 22465994: 127,715 samples/s, accuracy 0.879).
# A CPU fallback stays far below THROUGHPUT_MIN; ACCURACY_MIN leaves room for seed-to-seed variation.
THROUGHPUT_MIN=20000
ACCURACY_MIN=0.80

# THROUGHPUT: reported value within 5 %; ACCURACY is a rate: within 1 %.
ck_metric THROUGHPUT ge "$THROUGHPUT_MIN" rel
ck_metric ACCURACY ge "$ACCURACY_MIN" rate

# Evidence only (never changes the level): ranks, hosts and the NCCL transport of a DDP stretch run.
ck_topic_checks() {
    local log=$2 ranks hosts transport
    [ -f "$log" ] || return 0
    ranks=$({ grep -oE '^\[rank [0-9]+/[0-9]+\]' "$log" || true; } | sort -u | wc -l)
    [ "$ranks" -gt 1 ] || return 0
    hosts=$({ grep -oE '^\[rank [0-9]+/[0-9]+\] host=[^ ]+' "$log" || true; } | sed 's/.* host=//' | sort -u | wc -l)
    transport=$(grep -oE 'Using network [A-Za-z ]+' "$log" | sort -u | sed 's/Using network //' | paste -sd, - || true)
    ck_evidence ranks "$ranks"
    ck_evidence hosts "$hosts"
    ck_evidence transport "${transport:-unknown (set NCCL_DEBUG=INFO)}"
}

ck_main "$@"
