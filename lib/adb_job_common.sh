#!/usr/bin/env bash

ADB_ARGS=()

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

  local device_count
  device_count="$(adb devices | awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
  if [[ "${device_count}" != "1" ]]; then
    echo "Expected exactly one authorized adb device, found ${device_count}." >&2
    adb devices -l >&2
    echo "Set ADB_SERIAL=<serial> if multiple devices are connected." >&2
    exit 1
  fi

  local serial
  serial="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
  ADB_ARGS=(-s "${serial}")
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
  fi
}

swipe_list() {
  echo "swipe list: ${SWIPE_X},${SWIPE_START_Y} -> ${SWIPE_X},${SWIPE_END_Y} (${SWIPE_MS}ms)"
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    adb_run shell input swipe "${SWIPE_X}" "${SWIPE_START_Y}" "${SWIPE_X}" "${SWIPE_END_Y}" "${SWIPE_MS}"
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
  select_device
  prepare_screen
  print_config "${app_name}"
  pause_for "${START_DELAY}"

  local index
  for ((index = 1; index <= RUNS; index++)); do
    echo "--- ${app_name} iteration ${index}/${RUNS} ---"
    guard_page || exit 1
    if [[ "${SMART_TAP}" == "1" ]] && declare -F tap_visible_job >/dev/null && tap_visible_job; then
      :
    else
      tap_at "job card" "${JOB_X}" "${JOB_Y}"
    fi
    pause_for "${OPEN_DELAY}"
    if [[ "${SMART_TAP}" == "1" ]] && declare -F tap_communication_button >/dev/null && tap_communication_button; then
      :
    else
      tap_at "communication button" "${BUTTON_X}" "${BUTTON_Y}"
    fi
    pause_for "${POST_BUTTON_DELAY}"
    tap_at "back 1" "${BACK_X}" "${BACK_Y}"
    pause_for "${RETURN_DELAY}"
    tap_at "back 2" "${BACK_X}" "${BACK_Y}"
    pause_for "${RETURN_DELAY}"
    guard_page || exit 1
    if declare -F advance_one_job >/dev/null && advance_one_job; then
      :
    else
      swipe_list
    fi
    pause_for "${DELAY}"
  done
}