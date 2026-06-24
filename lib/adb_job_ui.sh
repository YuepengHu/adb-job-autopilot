#!/usr/bin/env bash

UI_DUMP_REMOTE="${UI_DUMP_REMOTE:-/sdcard/adb-job-ui.xml}"
UI_DUMP_LOCAL="${UI_DUMP_LOCAL:-${TMPDIR:-/tmp}/adb-job-ui-${USER:-user}.xml}"
UI_OCR_IMAGE="${UI_OCR_IMAGE:-${TMPDIR:-/tmp}/adb-job-screen-${USER:-user}.png}"

current_package() {
  adb_run shell dumpsys window | tr -d '\r' | awk '
    /mCurrentFocus|mFocusedApp/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[A-Za-z0-9_.]+\//) {
          split($i, parts, "/")
          print parts[1]
          exit
        }
      }
    }
  '
}

dump_ui() {
  adb_run shell uiautomator dump "${UI_DUMP_REMOTE}" >/dev/null 2>&1 || return 1
  adb_run exec-out cat "${UI_DUMP_REMOTE}" >"${UI_DUMP_LOCAL}"
}

xml_contains_regex() {
  local pattern="$1"
  perl -CS -0e '
    my ($pattern, $file) = @ARGV;
    open my $fh, "<:encoding(UTF-8)", $file or exit 1;
    local $/;
    my $xml = <$fh>;
    exit(($xml =~ /$pattern/) ? 0 : 1);
  ' "${pattern}" "${UI_DUMP_LOCAL}"
}

nodes_matching() {
  local pattern="$1"
  perl -CS -0e '
    my ($pattern, $file) = @ARGV;
    open my $fh, "<:encoding(UTF-8)", $file or exit 1;
    local $/;
    my $xml = <$fh>;
    while ($xml =~ /<node\b[^>]*>/g) {
      my $node = $&;
      print "$node\n" if $node =~ /$pattern/;
    }
  ' "${pattern}" "${UI_DUMP_LOCAL}"
}

node_attr() {
  local node="$1"
  local attr="$2"
  local regex="${attr}=\"([^\"]*)\""
  if [[ "${node}" =~ ${regex} ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

node_title() {
  local node="$1"
  local value
  value="$(node_attr "${node}" text)"
  if [[ -z "${value}" ]]; then
    value="$(node_attr "${node}" content-desc)"
  fi
  value="${value%%&#10;*}"
  value="${value//$'\n'/ }"
  value="${value//&amp;/&}"
  printf '%s' "${value}"
}

node_bounds() {
  local node="$1"
  local regex='bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]"'
  if [[ "${node}" =~ ${regex} ]]; then
    printf '%s %s %s %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
  fi
}

job_node_pattern() {
  case "${APP_KEY}" in
    boss)
      printf '%s' 'resource-id="com\.hpbr\.bosszhipin:id/tv_job_name"'
      ;;
    liepin)
      printf '%s' 'package="com\.lietou\.mishu"[^>]*class="android\.view\.View"[^>]*content-desc="[^"]*(薪资面议|[0-9]+-[0-9]+[Kk])[^"]*"[^>]*clickable="true"'
      ;;
    *)
      return 1
      ;;
  esac
}

visible_job_nodes() {
  local pattern
  pattern="$(job_node_pattern)" || return 1
  nodes_matching "${pattern}" | while IFS= read -r node; do
    local bounds title x1 y1 x2 y2 center_x center_y
    bounds="$(node_bounds "${node}")"
    [[ -n "${bounds}" ]] || continue
    read -r x1 y1 x2 y2 <<<"${bounds}"
    center_x=$(((x1 + x2) / 2))
    center_y=$(((y1 + y2) / 2))
    if ((center_y < JOB_MIN_Y || center_y > JOB_MAX_Y)); then
      continue
    fi
    title="$(node_title "${node}")"
    [[ -n "${title}" ]] || continue
    if [[ "${title}" =~ ^(推荐|最新|附近|区域|筛选|职位|消息|发现|我的|VIP|搜索)$ ]]; then
      continue
    fi
    printf '%s\t%s\t%s\n' "${center_x}" "${center_y}" "${title}"
  done
}

job_key_list() {
  visible_job_nodes | awk -F '\t' 'NF >= 3 { print $3 }' | head -4
}

tap_visible_job() {
  [[ "${DRY_RUN:-0}" == "1" ]] && return 1
  dump_ui || return 1
  local line center_x center_y title x
  line="$(visible_job_nodes | head -1)"
  [[ -n "${line}" ]] || return 1
  IFS=$'\t' read -r center_x center_y title <<<"${line}"
  x="${SMART_JOB_X:-${JOB_X}}"
  tap_at "job card (${title})" "${x}" "${center_y}"
}

find_text_node_center() {
  local text_pattern="$1"
  local min_y="${2:-0}"
  local node bounds x1 y1 x2 y2 center_x center_y
  nodes_matching "(text|content-desc)=\"[^\"]*(${text_pattern})[^\"]*\"" | while IFS= read -r node; do
    bounds="$(node_bounds "${node}")"
    [[ -n "${bounds}" ]] || continue
    read -r x1 y1 x2 y2 <<<"${bounds}"
    center_x=$(((x1 + x2) / 2))
    center_y=$(((y1 + y2) / 2))
    if ((center_y >= min_y)); then
      printf '%s %s\n' "${center_x}" "${center_y}"
      break
    fi
  done
}

ocr_screen_text() {
  [[ "${OCR_FALLBACK}" == "1" ]] || return 1
  command -v tesseract >/dev/null 2>&1 || return 1
  adb_run exec-out screencap -p >"${UI_OCR_IMAGE}" || return 1
  tesseract "${UI_OCR_IMAGE}" stdout -l chi_sim+eng --psm 6 2>/dev/null || tesseract "${UI_OCR_IMAGE}" stdout --psm 6 2>/dev/null
}

recover_unexpected_package() {
  local expected="$1"
  local attempt package
  for ((attempt = 1; attempt <= RECOVERY_BACKS; attempt++)); do
    echo "unexpected foreground package, pressing back (${attempt}/${RECOVERY_BACKS})"
    adb_run shell input keyevent BACK
    pause_for "${RETURN_DELAY}"
    package="$(current_package)"
    [[ "${package}" == "${expected}" ]] && return 0
  done
  return 1
}

recover_interruption() {
  local coords x y ocr_text
  coords="$(find_text_node_center "跳过|关闭广告|关闭|我知道了|稍后|取消" 0 | head -1)"
  if [[ -n "${coords}" ]]; then
    read -r x y <<<"${coords}"
    tap_at "interruption close" "${x}" "${y}"
    pause_for "${RETURN_DELAY}"
    return 0
  fi

  ocr_text="$(ocr_screen_text || true)"
  if [[ "${ocr_text}" =~ (广告|跳过|关闭|加载失败|网络异常|出错|重试) ]]; then
    echo "OCR detected interruption; pressing back once."
    adb_run shell input keyevent BACK
    pause_for "${RETURN_DELAY}"
    return 0
  fi

  return 1
}

guard_page() {
  [[ "${DRY_RUN:-0}" == "1" ]] && return 0
  [[ "${PAGE_GUARD}" == "1" ]] || return 0
  local package
  package="$(current_package)"
  if [[ -n "${APP_PACKAGE}" && "${package}" != "${APP_PACKAGE}" ]]; then
    echo "expected package ${APP_PACKAGE}, found ${package:-unknown}"
    recover_unexpected_package "${APP_PACKAGE}" || return 1
  fi

  dump_ui || return 0
  if xml_contains_regex '跳过|关闭广告|加载失败|网络异常|出错了|重新加载|请登录|登录后'; then
    echo "possible interruption detected in UI tree"
    recover_interruption || return 1
  fi
}

tap_communication_button() {
  [[ "${DRY_RUN:-0}" == "1" ]] && return 1
  local attempt coords x y ocr_text
  for ((attempt = 1; attempt <= BUTTON_FIND_ATTEMPTS; attempt++)); do
    dump_ui || true
    coords="$(find_text_node_center "${COMMUNICATION_SKIP_TEXT_REGEX}" "${BUTTON_MIN_Y}" | head -1)"
    if [[ -n "${coords}" ]]; then
      echo "already connected button detected; returning without tapping communication."
      COMMUNICATION_RESULT="already_connected"
      return 0
    fi

    if xml_contains_regex "(text|content-desc)=\"[^\"]*(${COMMUNICATION_SKIP_TEXT_REGEX})"; then
      echo "already connected text detected; returning without tapping communication."
      COMMUNICATION_RESULT="already_connected"
      return 0
    fi

    coords="$(find_text_node_center "${COMMUNICATION_APPLY_TEXT_REGEX}" "${BUTTON_MIN_Y}" | head -1)"
    if [[ -n "${coords}" ]]; then
      read -r x y <<<"${coords}"
      tap_at "communication button" "${x}" "${y}"
      COMMUNICATION_RESULT="tapped"
      return 0
    fi
    pause_for "${BUTTON_FIND_DELAY}"
  done

  ocr_text="$(ocr_screen_text || true)"
  if [[ "${ocr_text}" =~ ${COMMUNICATION_SKIP_TEXT_REGEX} ]]; then
    echo "already connected text detected by OCR; returning without tapping communication."
    COMMUNICATION_RESULT="already_connected"
    return 0
  fi
  return 1
}

smart_scroll_once() {
  echo "smart swipe: ${STEP_SWIPE_X},${STEP_SWIPE_START_Y} -> ${STEP_SWIPE_X},${STEP_SWIPE_END_Y} (${STEP_SWIPE_MS}ms)"
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    adb_run shell input swipe "${STEP_SWIPE_X}" "${STEP_SWIPE_START_Y}" "${STEP_SWIPE_X}" "${STEP_SWIPE_END_Y}" "${STEP_SWIPE_MS}"
  fi
}

advance_one_job() {
  [[ "${DRY_RUN:-0}" == "1" ]] && return 1
  [[ "${SMART_SCROLL}" == "1" ]] || return 1
  dump_ui || return 1

  local before_jobs before_first before_second after_jobs after_first attempt
  before_jobs="$(job_key_list)"
  before_first="$(printf '%s\n' "${before_jobs}" | sed -n '1p')"
  before_second="$(printf '%s\n' "${before_jobs}" | sed -n '2p')"
  [[ -n "${before_first}" ]] || return 1

  for ((attempt = 1; attempt <= SMART_SCROLL_MAX_STEPS; attempt++)); do
    smart_scroll_once
    pause_for "${SMART_SCROLL_SETTLE}"
    dump_ui || continue
    after_jobs="$(job_key_list)"
    after_first="$(printf '%s\n' "${after_jobs}" | sed -n '1p')"
    [[ -n "${after_first}" ]] || continue
    if ((attempt < SMART_SCROLL_MIN_STEPS)); then
      continue
    fi
    if [[ "${after_first}" != "${before_first}" ]]; then
      echo "advanced from '${before_first}' to '${after_first}'"
      if [[ -n "${before_second}" && "${after_first}" != "${before_second}" ]]; then
        echo "warning: first visible job is not the previous second job; scroll may have skipped." >&2
      fi
      return 0
    fi
  done

  echo "could not verify one-job advancement after ${SMART_SCROLL_MAX_STEPS} small swipes" >&2
  return 1
}