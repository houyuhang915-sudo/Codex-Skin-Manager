#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-run}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP_NAME="Codex 皮肤管理器"
PROCESS_NAME="CodexSkinManager"
APP_BUNDLE="$ROOT/dist/$APP_NAME.app"

/usr/bin/pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
/bin/mkdir -p "$ROOT/dist"
"$ROOT/macos/scripts/build-studio-app-macos.sh" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    /usr/bin/lldb -- "$APP_BUNDLE/Contents/MacOS/$PROCESS_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$PROCESS_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate 'subsystem == "com.codexdreamskin.studio"'
    ;;
  --verify|verify)
    open_app
    /bin/sleep 1
    /usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null
    ;;
  *)
    printf 'usage: %s [run|--debug|--logs|--telemetry|--verify]\n' "$0" >&2
    exit 2
    ;;
esac
