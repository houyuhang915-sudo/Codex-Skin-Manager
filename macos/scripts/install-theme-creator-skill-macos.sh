#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

SOURCE="$PROJECT_ROOT/skill/codex-skin-theme-creator"
if [ ! -f "$SOURCE/SKILL.md" ]; then
  SOURCE="$(cd "$PROJECT_ROOT/.." && pwd -P)/skill/codex-skin-theme-creator"
fi
[ -f "$SOURCE/SKILL.md" ] || fail "Theme creator Skill is missing."

CODEX_SKILLS_HOME="${CODEX_HOME:-$HOME/.codex}/skills"
TARGET="$CODEX_SKILLS_HOME/codex-skin-theme-creator"
STAGING="$CODEX_SKILLS_HOME/.codex-skin-theme-creator.installing.$$"
BACKUP="$CODEX_SKILLS_HOME/.codex-skin-theme-creator.backup.$$"

/bin/mkdir -p "$CODEX_SKILLS_HOME"
/bin/rm -rf "$STAGING" "$BACKUP"
/usr/bin/ditto "$SOURCE" "$STAGING"
if [ -e "$TARGET" ]; then /bin/mv "$TARGET" "$BACKUP"; fi
if ! /bin/mv "$STAGING" "$TARGET"; then
  [ -e "$BACKUP" ] && /bin/mv "$BACKUP" "$TARGET"
  fail "Could not install the Codex theme creator Skill."
fi
/bin/rm -rf "$BACKUP"
/bin/chmod 755 "$TARGET/scripts/create-theme.mjs"

printf 'Installed Codex theme creator Skill at %s.\n' "$TARGET"
