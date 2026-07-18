#!/bin/bash

# Switch to a theme pack under themes/<id>/ — hot path when CDP is live.

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

THEME_ID=""
APPLY_NOW="true"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --id) THEME_ID="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[ -n "$THEME_ID" ] || fail "Usage: switch-theme-macos.sh --id <theme-id>"

ensure_state_root
SRC="$THEMES_ROOT/$THEME_ID"
[ -d "$SRC" ] || fail "Theme not found: $THEME_ID"
[ -f "$SRC/theme.json" ] || fail "theme.json missing in $THEME_ID"

progress() {
  printf '%s\n' "$*" >&2
  /usr/bin/osascript -e "display notification \"$*\" with title \"Codex 皮肤管理器\"" >/dev/null 2>&1 || true
}

ensure_node_runtime
THEME_META="$("$NODE" -e '
  const value = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
  process.stdout.write(`${value.name || ""}\n${value.mode || "theme"}`);
' "$SRC/theme.json")"
THEME_NAME="$(printf '%s\n' "$THEME_META" | /usr/bin/sed -n '1p')"
THEME_MODE="$(printf '%s\n' "$THEME_META" | /usr/bin/sed -n '2p')"
[ -n "$THEME_NAME" ] || THEME_NAME="$THEME_ID"

progress "Switching..."

if [ "$THEME_MODE" = "original" ]; then
  if [ "$APPLY_NOW" != "true" ]; then
    progress "Ready: ${THEME_NAME} (not applied)"
    exit 0
  fi
  "$SCRIPT_DIR/pause-dream-skin-macos.sh" >/dev/null
  progress "Done: ${THEME_NAME}"
  exit 0
fi

/bin/mkdir -p "$THEME_DIR"
/usr/bin/find "$THEME_DIR" -type f -maxdepth 1 -delete 2>/dev/null || true
THEME_IMAGE="$("$NODE" -e '
  const fs = require("node:fs");
  const path = require("node:path");
  const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (typeof value.image !== "string" || path.basename(value.image) !== value.image) process.exit(2);
  process.stdout.write(value.image);
' "$SRC/theme.json")"
[ -f "$SRC/$THEME_IMAGE" ] || fail "Theme image missing in $THEME_ID: $THEME_IMAGE"
/bin/cp -f "$SRC/theme.json" "$SRC/$THEME_IMAGE" "$THEME_DIR/"
/bin/chmod 600 "$THEME_DIR/"* 2>/dev/null || true

if [ "$APPLY_NOW" != "true" ]; then
  progress "Ready: ${THEME_NAME} (not applied)"
  exit 0
fi

PORT=9341
if [ -f "$STATE_PATH" ]; then
  saved="$(state_field port 2>/dev/null || true)"
  [ -n "${saved:-}" ] && PORT="$saved"
fi

# Hot path: CDP already open → seconds, not tens of seconds
if hot_reapply_theme "$PORT" 8000; then
  progress "Done: ${THEME_NAME}"
  exit 0
fi

# Cold path only when debug port is missing
progress "CDP not ready, full start..."
if "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing; then
  progress "Done: ${THEME_NAME}"
  exit 0
fi

/usr/bin/osascript -e 'display alert "Codex 皮肤管理器" message "主题已切换，但实时应用失败，请重新点击切换。"' >/dev/null 2>&1 || true
exit 1
