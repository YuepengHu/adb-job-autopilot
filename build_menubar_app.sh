#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ADB Job Autopilot"
APP_DIR="${SCRIPT_DIR}/dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

mkdir -p "${MACOS_DIR}"

swiftc -O -framework AppKit \
  "${SCRIPT_DIR}/menu_bar/JobAutopilotMenu.swift" \
  -o "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"

cat >"${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>local.adb-job-autopilot</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "Built ${APP_DIR}"

if [[ "${1:-}" == "--open" ]]; then
  if pgrep -f "${MACOS_DIR}/${APP_NAME}" >/dev/null 2>&1; then
    echo "${APP_NAME} is already running"
  else
    ADB_JOB_AUTOPILOT_HOME="${SCRIPT_DIR}" MENU_RUNS="${MENU_RUNS:-5}" "${MACOS_DIR}/${APP_NAME}" >/dev/null 2>&1 &
    echo "Opened ${APP_NAME}"
  fi
fi