#!/usr/bin/env bash

# starts android auto via HU

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -s)" in
  Darwin) DEFAULT_SDK="$HOME/Library/Android/sdk" ;;
  *) DEFAULT_SDK="$HOME/Android/Sdk" ;;
esac
case "$(uname -m)" in
  arm64|aarch64) ABI="arm64-v8a" ;;
  *) ABI="x86_64" ;;
esac
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$DEFAULT_SDK}}"
AVD="${AVD:-cosmo_auto}"
IMAGE="${IMAGE:-system-images;android-35;google_apis_playstore;$ABI}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
DHU="$SDK/extras/google/auto/desktop-head-unit"
CONFIG="$HOME/.android/avd/$AVD.avd/config.ini"
AUTO_PACKAGE="com.google.android.projection.gearhead"
APP_APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
CACHE="$ROOT/tools/.cache"
AUTO_CACHE="$CACHE/android-auto"
AVD_HOME="$HOME/.android/avd"
DEFAULT_IMAGE_FILE="$CACHE/$AVD-avd.tar.gz"

AUTO_APK=""
INSTALL_APP=0
HEAD_UNIT=1
MODE="run"
IMAGE_FILE=""

usage() {
  cat <<USAGE
usage: tools/android-auto.sh [--auto-apk <file.apk|file.apks|file.xapk|dir>] [--app] [--no-head-unit]
       tools/android-auto.sh --pull-auto
       tools/android-auto.sh --save-image [file]
       tools/android-auto.sh --restore-image [file]

  --auto-apk       install or update Android Auto from a local apk, split apk bundle or folder
  --app            build and install the cosmodrome debug apk
  --no-head-unit   only start the emulator
  --pull-auto      copy the installed Android Auto apks into tools/.cache for reuse
  --save-image     stop the emulator and archive the avd (default tools/.cache/<avd>-avd.tar.gz)
  --restore-image  replace the avd with an archived one, then start it
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --auto-apk) AUTO_APK="${2:?missing path}"; shift 2 ;;
    --app) INSTALL_APP=1; shift ;;
    --no-head-unit) HEAD_UNIT=0; shift ;;
    --pull-auto) MODE="pull"; shift ;;
    --save-image|--restore-image)
      MODE="${1#--}"
      shift
      if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then IMAGE_FILE="$1"; shift; fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [ -z "${JAVA_HOME:-}" ] && [ -d /opt/homebrew/opt/openjdk@21 ]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
fi

tool() {
  ls -d "$SDK"/cmdline-tools/*/bin/"$1" | tail -1
}

set_config() {
  grep -v "^$1=" "$CONFIG" > "$CONFIG.tmp" || true
  echo "$1=$2" >> "$CONFIG.tmp"
  mv "$CONFIG.tmp" "$CONFIG"
}

install_auto() {
  local source="$1"
  local dir="$source"
  if [ -f "$source" ]; then
    case "$source" in
      *.apk) "$ADB" install -r -d "$source"; return ;;
      *)
        dir="$(mktemp -d)"
        unzip -q -o "$source" -d "$dir"
        ;;
    esac
  fi
  local apks=()
  while IFS= read -r apk; do apks+=("$apk"); done < <(find "$dir" -name '*.apk' | sort)
  [ "${#apks[@]}" -gt 0 ] || { echo "no apk files found in $source"; exit 1; }
  "$ADB" install-multiple -r -d "${apks[@]}"
}

running() {
  "$ADB" devices | grep -q '^emulator-.*device$'
}

stop_emulator() {
  if running; then
    "$ADB" emu kill > /dev/null || true
    while pgrep -f "qemu-system.*-avd $AVD" > /dev/null; do sleep 1; done
  fi
}

IMAGE_FILE="${IMAGE_FILE:-$DEFAULT_IMAGE_FILE}"

if [ "$MODE" = "pull" ]; then
  running || { echo "start the emulator first"; exit 1; }
  rm -rf "$AUTO_CACHE"
  mkdir -p "$AUTO_CACHE"
  "$ADB" shell pm path "$AUTO_PACKAGE" | tr -d '\r' | sed 's/^package://' | while read -r apk; do
    "$ADB" pull "$apk" "$AUTO_CACHE/" > /dev/null 2>&1
  done
  ls "$AUTO_CACHE" | wc -l | xargs echo "apks saved to $AUTO_CACHE:"
  exit 0
fi

if [ "$MODE" = "save-image" ]; then
  [ -d "$AVD_HOME/$AVD.avd" ] || { echo "no avd named $AVD"; exit 1; }
  stop_emulator
  mkdir -p "$(dirname "$IMAGE_FILE")"
  tar -czf "$IMAGE_FILE" -C "$AVD_HOME" --exclude='*.lock' --exclude='snapshots' "$AVD.avd" "$AVD.ini"
  du -h "$IMAGE_FILE"
  exit 0
fi

if [ "$MODE" = "restore-image" ]; then
  [ -f "$IMAGE_FILE" ] || { echo "no image at $IMAGE_FILE"; exit 1; }
  stop_emulator
  rm -rf "$AVD_HOME/$AVD.avd" "$AVD_HOME/$AVD.ini"
  mkdir -p "$AVD_HOME"
  tar -xzf "$IMAGE_FILE" -C "$AVD_HOME"
  grep -v '^path=' "$AVD_HOME/$AVD.ini" > "$AVD_HOME/$AVD.ini.tmp"
  echo "path=$AVD_HOME/$AVD.avd" >> "$AVD_HOME/$AVD.ini.tmp"
  mv "$AVD_HOME/$AVD.ini.tmp" "$AVD_HOME/$AVD.ini"
fi

if ! "$EMULATOR" -list-avds | grep -qx "$AVD"; then
  yes | "$(tool sdkmanager)" "$IMAGE" "extras;google;auto" > /dev/null
  echo no | "$(tool avdmanager)" create avd -n "$AVD" -k "$IMAGE" -d pixel_7
fi

set_config hw.gpu.enabled yes
set_config hw.gpu.mode host
set_config hw.keyboard yes
set_config hw.ramSize 4096
set_config hw.cpu.ncore 4
set_config PlayStore.enabled yes

if ! running; then
  nohup "$EMULATOR" -avd "$AVD" -gpu host -no-snapshot-save > "${TMPDIR:-/tmp}/$AVD.log" 2>&1 &
fi

"$ADB" wait-for-device
booted() {
  "$ADB" shell getprop sys.boot_completed 2>/dev/null | grep -q 1
}

until booted; do
  sleep 2
done

stub() {
  "$ADB" shell dumpsys package "$AUTO_PACKAGE" | grep -q 'versionName=.*stub'
}

if [ -z "$AUTO_APK" ] && [ -d "$AUTO_CACHE" ] && stub; then
  AUTO_APK="$AUTO_CACHE"
fi

if [ -n "$AUTO_APK" ]; then
  install_auto "$AUTO_APK"
fi

if [ "$INSTALL_APP" = 1 ]; then
  (cd "$ROOT" && flutter build apk --debug)
  "$ADB" install -r "$APP_APK"
fi

"$ADB" shell dumpsys package "$AUTO_PACKAGE" | grep -m1 versionName

if [ "$HEAD_UNIT" = 1 ]; then
  if stub; then
    echo "android auto is still the stub build, pass --auto-apk or update it in the play store"
    exit 1
  fi
  "$ADB" forward tcp:5277 tcp:5277
  echo "in android auto: settings > version (tap 10x) > menu > start head unit server"
  cd "$(dirname "$DHU")"
  exec "$DHU"
fi
