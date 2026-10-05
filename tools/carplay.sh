#!/usr/bin/env bash

## starts an emulator with carplay 

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DEVICE:-iPhone 17}"
BUNDLE_ID="me.rmfosho.cosmodrome"
APP="$ROOT/build/ios/iphonesimulator/Runner.app"

BUILD=0

usage() {
  cat <<USAGE
usage: tools/carplay.sh [--build]

  --build   build and install the cosmodrome simulator app before launching

  DEVICE="iPhone 17 Pro" tools/carplay.sh   pick another simulator
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --build) BUILD=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

UDID="$(xcrun simctl list devices available | grep -F "$DEVICE (" | head -1 | grep -oE '[0-9A-F-]{36}')"
[ -n "$UDID" ] || { echo "no simulator named $DEVICE"; exit 1; }

xcrun simctl bootstatus "$UDID" -b > /dev/null
open -a Simulator --args -CurrentDeviceUDID "$UDID"

if [ "$BUILD" = 1 ]; then
  # build
  (cd "$ROOT" && flutter build ios --simulator --debug)
fi

if [ -d "$APP" ] && { [ "$BUILD" = 1 ] || ! xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" > /dev/null 2>&1; }; then
  xcrun simctl install "$UDID" "$APP"
fi

display() {
  osascript > /dev/null <<OSA
tell application "System Events" to tell process "Simulator"
  click menu item "$1" of menu 1 of menu item "External Displays" of menu 1 of menu bar item "I/O" of menu bar 1
end tell
OSA
}

sleep 2
display "Disabled" || true
sleep 1
display "CarPlay"

xcrun simctl launch "$UDID" "$BUNDLE_ID" > /dev/null || echo "cosmodrome is not installed, run with --build"
echo "carplay is up on $DEVICE, if it ignores clicks run this again"
