#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RUNS="${RUNS:-1}"
DELAY="${DELAY:-1}"
START_DELAY="${START_DELAY:-2}"
OPEN_DELAY="${OPEN_DELAY:-2}"
POST_BUTTON_DELAY="${POST_BUTTON_DELAY:-2}"
RETURN_DELAY="${RETURN_DELAY:-1}"

JOB_X="${JOB_X:-630}"
JOB_Y="${JOB_Y:-720}"
BUTTON_X="${BUTTON_X:-990}"
BUTTON_Y="${BUTTON_Y:-2585}"
BACK_X="${BACK_X:-70}"
BACK_Y="${BACK_Y:-220}"
SWIPE_X="${SWIPE_X:-630}"
SWIPE_START_Y="${SWIPE_START_Y:-1850}"
SWIPE_END_Y="${SWIPE_END_Y:-1290}"
SWIPE_MS="${SWIPE_MS:-350}"

source "${SCRIPT_DIR}/lib/adb_job_common.sh"

run_apply_loop "Liepin"