#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

DMG_PATH="${1:-}"
[ -n "$DMG_PATH" ] || fail "Usage: verify-installer-dmg-macos.sh <installer.dmg>"
[ -s "$DMG_PATH" ] || fail "Installer DMG is missing or empty: $DMG_PATH"

TMP="$(/usr/bin/mktemp -d /tmp/codex-skin-dmg-verify.XXXXXX)"
MOUNT_POINT="$TMP/mount"
MOUNTED="false"
cleanup() {
  if [ "$MOUNTED" = "true" ]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf "$TMP"
}
trap cleanup EXIT

/bin/mkdir -p "$MOUNT_POINT"
/usr/bin/hdiutil attach \
  -nobrowse \
  -readonly \
  -mountpoint "$MOUNT_POINT" \
  "$DMG_PATH" >/dev/null
MOUNTED="true"

INSTALLER_APP="$MOUNT_POINT/安装 Codex 皮肤管理器.app"
PAYLOAD="$INSTALLER_APP/Contents/Resources/Payload"
MANAGER_APP="$INSTALLER_APP/Contents/Resources/Codex 皮肤管理器.app"
[ -d "$INSTALLER_APP" ] || fail "Installer application is missing from the DMG."
[ -x "$PAYLOAD/scripts/install-dream-skin-macos.sh" ] \
  || fail "Installer payload entry point is missing or not executable."
[ -d "$PAYLOAD/themes" ] || fail "Installer payload does not contain built-in themes."
[ -x "$MANAGER_APP/Contents/MacOS/CodexSkinManager" ] \
  || fail "Bundled manager application is incomplete."

installer_version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw \
  "$INSTALLER_APP/Contents/Info.plist")"
manager_version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw \
  "$MANAGER_APP/Contents/Info.plist")"
[ "$installer_version" = "$SKIN_VERSION" ] \
  || fail "Installer version $installer_version does not match $SKIN_VERSION."
[ "$manager_version" = "$SKIN_VERSION" ] \
  || fail "Manager version $manager_version does not match $SKIN_VERSION."

expected_count=0
for source in "$BUILTIN_THEMES_ROOT"/*; do
  [ -d "$source" ] || continue
  theme_id="$(/usr/bin/basename "$source")"
  expected_count=$((expected_count + 1))
  packaged="$PAYLOAD/themes/$theme_id"
  [ -d "$packaged" ] || fail "DMG is missing built-in theme: $theme_id"
  for filename in theme.json background.png preview.png; do
    [ -s "$packaged/$filename" ] \
      || fail "DMG theme $theme_id is missing $filename."
  done
  /usr/bin/cmp -s "$source/theme.json" "$packaged/theme.json" \
    || fail "DMG theme manifest differs from source: $theme_id"
done

actual_count="$(/usr/bin/find "$PAYLOAD/themes" -mindepth 1 -maxdepth 1 -type d \
  | /usr/bin/wc -l | /usr/bin/awk '{$1=$1; print}')"
[ "$actual_count" -eq "$expected_count" ] \
  || fail "DMG contains $actual_count themes; expected $expected_count."

# Prove that the exact script shipped in the DMG restores the complete catalog
# into a clean user data directory.
TEST_HOME="$TMP/home"
/bin/mkdir -p "$TEST_HOME"
HOME="$TEST_HOME" /bin/bash "$PAYLOAD/scripts/install-builtin-themes-macos.sh" >/dev/null
installed_root="$TEST_HOME/Library/Application Support/CodexDreamSkinStudio/themes"
installed_count="$(/usr/bin/find "$installed_root" -mindepth 1 -maxdepth 1 -type d \
  | /usr/bin/wc -l | /usr/bin/awk '{$1=$1; print}')"
[ "$installed_count" -eq "$expected_count" ] \
  || fail "DMG install fixture restored $installed_count themes; expected $expected_count."
for source in "$BUILTIN_THEMES_ROOT"/*; do
  [ -d "$source" ] || continue
  theme_id="$(/usr/bin/basename "$source")"
  /usr/bin/cmp -s "$source/theme.json" "$installed_root/$theme_id/theme.json" \
    || fail "Installed fixture theme differs from source: $theme_id"
done

/usr/bin/printf \
  'Verified DMG %s: version %s, manager executable, and %s installable built-in themes.\n' \
  "$DMG_PATH" "$SKIN_VERSION" "$expected_count"
