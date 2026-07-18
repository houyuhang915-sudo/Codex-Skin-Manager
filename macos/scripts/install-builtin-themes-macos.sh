#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

ensure_state_root
/bin/mkdir -p "$THEMES_ROOT"
[ -d "$BUILTIN_THEMES_ROOT" ] || exit 0

for source in "$BUILTIN_THEMES_ROOT"/*; do
  [ -d "$source" ] || continue
  [ -f "$source/theme.json" ] || fail "Built-in theme is missing theme.json: $source"
  theme_id="$(/usr/bin/basename "$source")"
  case "$theme_id" in ''|*[!a-zA-Z0-9-]*) fail "Invalid built-in theme id: $theme_id" ;; esac
  temporary="$THEMES_ROOT/.${theme_id}.installing.$$"
  destination="$THEMES_ROOT/$theme_id"
  /bin/rm -rf "$temporary"
  /bin/mkdir -p "$temporary"
  /usr/bin/rsync -a --exclude '.DS_Store' "$source/" "$temporary/"
  /bin/rm -rf "$destination"
  /bin/mv "$temporary" "$destination"
  /bin/chmod 700 "$destination"
  /bin/chmod 600 "$destination"/* 2>/dev/null || true
done

printf 'Installed built-in Dream Skin themes into %s.\n' "$THEMES_ROOT"
