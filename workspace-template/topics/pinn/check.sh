#!/usr/bin/env bash
# topics/pinn/check.sh: acceptance levels for the pinn topic. Run it as `ws-check pinn`, which uses the
# kit's read-only copy; editing the workspace copy changes nothing. Logic: lib/check-common.sh.
set -euo pipefail

CHECK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CK_LIB=${WS_KIT_RO:-}/lib/check-common.sh
if [ -z "${WS_KIT_RO:-}" ] || [ ! -f "$CK_LIB" ]; then CK_LIB=$CHECK_DIR/../../../lib/check-common.sh; fi
# shellcheck source-path=SCRIPTDIR source=../../../lib/check-common.sh
. "$CK_LIB"

CK_TOPIC=pinn
CK_PLOT=pinn.png

# Level-2 threshold, calibrated 2026-09-27 on one A40 (job 22466011: L2_ERROR 7.55e-4 after 8k Adam steps);
# 2e-2 leaves room for other seeds and tailored runs.
L2_ERROR_MAX=2e-2

# Errors: reported value within 5 % or 1e-3 absolute. PDE_RESIDUAL must be present (no threshold).
ck_metric L2_ERROR le "$L2_ERROR_MAX" err
ck_metric PDE_RESIDUAL present - err
ck_metric TRAIN_SECONDS present - rel optional

ck_main "$@"
