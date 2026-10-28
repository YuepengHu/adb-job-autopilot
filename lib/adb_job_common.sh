#!/usr/bin/env bash

ADB_ARGS=()
CURRENT_ITERATION=0
STATE_APP_NAME=""

emit_state() {
  local step="$1"
  local message="${2:-}"
  printf 'STATE|%s|%s|%s|%s|%s\n' "${STATE_APP_NAME}" "${CURRENT_ITERATION}" "${RUNS}" "${step}" "${message}"
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb is not available in PATH. Install Android platform-tools first." >&2
    exit 1
  fi
}

select_device() {
  require_adb

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY_RUN=1: skipping adb device validation."
    ADB_ARGS=()
    return
  fi

  if [[ -n "${ADB_SERIAL:-}" ]]; then
    local state
    state="$(adb devices | awk -v serial="${ADB_SERIAL}" '$1 == serial { print $2 }')"
    if [[ "${state}" != "device" ]]; then
      echo "ADB_SERIAL=${ADB_SERIAL} is not connected as an authorized device." >&2
      adb devices -l >&2
      exit 1
    fi
    ADB_ARGS=(-s "${ADB_SERIAL}")
    return
  fi

  # Wireless adb (adb connect / Android 11+ pairing) reports its serial as host:port; prefer it over USB.
  emit_state "check_adb" "checking wireless adb"
  local wireless_count
  wireless_count="$(adb devices | awk 'NR > 1 && $2 == "device" && $1 ~ /:[0-9]+$/ { count++ } END { print count + 0 }')"
  if [[ "${wireless_count}" == "1" ]]; then
    local wireless_serial
    wireless_serial="$(adb devices | awk 'NR > 1 && $2 == "device" && $1 ~ /:[0-9]+$/ { print $1; exit }')"
    ADB_ARGS=(-s "${wireless_serial}")
    emit_state "check_adb" "wireless adb connected: ${wireless_serial}"
    return
  elif [[ "${wireless_count}" != "0" ]]; then
    echo "Expected exactly one authorized wireless adb device, found ${wireless_count}." >&2
    adb devices -l >&2
    echo "Set ADB_SERIAL=<serial> to pick one." >&2
    exit 1
  fi

  emit_state "check_adb" "no wireless adb, checking wired adb"
  local wired_count
  wired_count="$(adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /:[0-9]+$/ { count++ } END { print count + 0 }')"
  if [[ "${wired_count}" == "1" ]]; then
    local wired_serial
    wired_serial="$(adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /:[0-9]+$/ { print $1; exit }')"
    ADB_ARGS=(-s "${wired_serial}")
    emit_state "check_adb" "wired adb connected: ${wired_serial}"
    return
  elif [[ "${wired_count}" != "0" ]]; then
    echo "Expected exactly one authorized wired adb device, found ${wired_count}." >&2
    adb devices -l >&2
    echo "Set ADB_SERIAL=<serial> to pick one." >&2
    exit 1
  fi

  emit_state "failed" "no wireless or wired adb device found"
  echo "No authorized adb device found (checked wireless then wired)." >&2
  adb devices -l >&2
  exit 1
}

adb_run() {
  if ((${#ADB_ARGS[@]} > 0)); then
    adb "${ADB_ARGS[@]}" "$@"
  else
    adb "$@"
  fi
}

tap_at() {
  local label="$1"
  local x="$2"
  local y="$3"
  echo "tap ${label}: ${x},${y}"
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    adb_run shell input tap "${x}" "${y}"
    declare -F invalidate_ui_cache >/dev/null && invalidate_ui_cache
  fi
}

swipe_list() {
  echo "swipe list: ${SWIPE_X},${SWIPE_START_Y} -> ${SWIPE_X},${SWIPE_END_Y} (${SWIPE_MS}ms)"
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    adb_run shell input swipe "${SWIPE_X}" "${SWIPE_START_Y}" "${SWIPE_X}" "${SWIPE_END_Y}" "${SWIPE_MS}"
    declare -F invalidate_ui_cache >/dev/null && invalidate_ui_cache
  fi
}

pause_for() {
  local seconds="$1"
  if [[ "${seconds}" != "0" ]]; then
    sleep "${seconds}"
  fi
}

print_config() {
  local app_name="$1"
  echo "App: ${app_name}"
  echo "RUNS=${RUNS} DELAY=${DELAY} OPEN_DELAY=${OPEN_DELAY} POST_BUTTON_DELAY=${POST_BUTTON_DELAY} RETURN_DELAY=${RETURN_DELAY}"
  echo "JOB=${JOB_X},${JOB_Y} BUTTON=${BUTTON_X},${BUTTON_Y} BACK=${BACK_X},${BACK_Y}"
  echo "SWIPE=${SWIPE_X},${SWIPE_START_Y}->${SWIPE_X},${SWIPE_END_Y} ${SWIPE_MS}ms"
  echo "SMART_TAP=${SMART_TAP} SMART_SCROLL=${SMART_SCROLL} PAGE_GUARD=${PAGE_GUARD} OCR_FALLBACK=${OCR_FALLBACK}"
  echo "DRY_RUN=${DRY_RUN:-0} WAKE_SCREEN=${WAKE_SCREEN} KEEP_AWAKE=${KEEP_AWAKE}"
}

prepare_screen() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    return
  fi

  if [[ "${WAKE_SCREEN}" == "1" ]]; then
    adb_run shell input keyevent WAKEUP || true
  fi

  if [[ "${KEEP_AWAKE}" == "1" ]]; then
    adb_run shell svc power stayon usb || true
  fi
}

run_apply_loop() {
  local app_name="$1"
  STATE_APP_NAME="${app_name}"
  select_device
  emit_state "prepare" "select device"
  prepare_screen
  print_config "${app_name}"
  pause_for "${START_DELAY}"

  local index
  for ((index = 1; index <= RUNS; index++)); do
    CURRENT_ITERATION="${index}"
    echo "--- ${app_name} iteration ${index}/${RUNS} ---"
    emit_state "verify_list" "verify list page"
    guard_page || { emit_state "failed" "page guard failed"; exit 1; }
    emit_state "open_job" "open visible job"
    if [[ "${SMART_TAP}" == "1" ]] && declare -F tap_visible_job >/dev/null && tap_visible_job; then
      :
    else
      tap_at "job card" "${JOB_X}" "${JOB_Y}"
    fi
    pause_for "${OPEN_DELAY}"
    emit_state "detect_button" "tap communication button"
    tap_at "communication button" "${BUTTON_X}" "${BUTTON_Y}"
    emit_state "communicate" "communication tapped"
    pause_for "${POST_BUTTON_DELAY}"
    local return_backs=2
    emit_state "return_list" "back to list"
    local back_index
    for ((back_index = 1; back_index <= return_backs; back_index++)); do
      tap_at "back ${back_index}/${return_backs}" "${BACK_X}" "${BACK_Y}"
      pause_for "${RETURN_DELAY}"
    done
    emit_state "verify_return" "verify returned list"
    guard_page || { emit_state "failed" "return guard failed"; exit 1; }
    emit_state "scroll" "advance one job"
    if declare -F advance_one_job >/dev/null && advance_one_job; then
      :
    else
      swipe_list
    fi
    emit_state "iteration_done" "iteration ${index} complete"
    pause_for "${DELAY}"
  done
  emit_state "run_complete" "run complete"
}