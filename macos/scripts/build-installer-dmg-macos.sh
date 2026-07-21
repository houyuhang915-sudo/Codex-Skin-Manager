#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

OUTPUT="${1:-$HOME/Desktop/Codex 皮肤管理器 ${SKIN_VERSION}.dmg}"
REPOSITORY_ROOT="$(cd "$PROJECT_ROOT/.." && pwd -P)"
TMP="$(/usr/bin/mktemp -d /tmp/codex-dream-skin-dmg.XXXXXX)"
DMG_ROOT="$TMP/Codex 皮肤管理器"
INSTALLER_APP="$DMG_ROOT/安装 Codex 皮肤管理器.app"
MANAGER_APP="$TMP/Codex 皮肤管理器.app"
SOURCE="$PROJECT_ROOT/installer/DreamSkinInstaller.swift"
PLIST="$PROJECT_ROOT/installer/Info.plist"
ICON="$PROJECT_ROOT/assets/DreamSkinAppIcon.icns"
trap '/bin/rm -rf "$TMP"' EXIT

[ -f "$SOURCE" ] || fail "Installer source is missing: $SOURCE"
[ -f "$PLIST" ] || fail "Installer Info.plist is missing: $PLIST"
[ -s "$ICON" ] || fail "Installer icon is missing: $ICON"
/usr/bin/xcrun --find swiftc >/dev/null 2>&1 || fail "Swift compiler is required to build the installer."

"$SCRIPT_DIR/build-studio-app-macos.sh" "$MANAGER_APP"
/bin/mkdir -p \
  "$INSTALLER_APP/Contents/MacOS" \
  "$INSTALLER_APP/Contents/Resources/Payload"

/usr/bin/xcrun swiftc \
  -parse-as-library \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  "$SOURCE" \
  -o "$INSTALLER_APP/Contents/MacOS/CodexSkinManagerInstaller"
/bin/cp "$PLIST" "$INSTALLER_APP/Contents/Info.plist"
/bin/cp "$ICON" "$INSTALLER_APP/Contents/Resources/DreamSkinAppIcon.icns"
/usr/bin/ditto "$MANAGER_APP" "$INSTALLER_APP/Contents/Resources/Codex 皮肤管理器.app"
/usr/bin/rsync -a \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude 'release/' \
  --exclude 'runtime/' \
  "$PROJECT_ROOT/" "$INSTALLER_APP/Contents/Resources/Payload/"
/bin/mkdir -p "$INSTALLER_APP/Contents/Resources/Payload/skill"
/usr/bin/ditto \
  "$REPOSITORY_ROOT/skill/codex-skin-theme-creator" \
  "$INSTALLER_APP/Contents/Resources/Payload/skill/codex-skin-theme-creator"
/bin/chmod 700 "$INSTALLER_APP/Contents/Resources/Payload"/*.command 2>/dev/null || true
/bin/chmod 700 "$INSTALLER_APP/Contents/Resources/Payload"/scripts/*.sh
/bin/chmod 700 "$INSTALLER_APP/Contents/Resources/Payload"/tests/*.sh

/usr/bin/printf '%s\n' \
  "Codex 皮肤管理器 ${SKIN_VERSION}" \
  '' \
  '双击“安装 Codex 皮肤管理器.app”，然后点击“一键安装”。' \
  '安装完成后会自动打开皮肤管理器，并在桌面创建入口。' \
  > "$DMG_ROOT/使用说明.txt"

/usr/bin/xattr -cr "$DMG_ROOT"
/usr/bin/codesign --force --deep --sign - "$INSTALLER_APP" >/dev/null
/bin/mkdir -p "$(dirname "$OUTPUT")"
/bin/rm -f "$OUTPUT"
if ! /usr/bin/hdiutil create \
  -volname "Codex 皮肤管理器" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  -ov \
  "$OUTPUT" >/dev/null; then
  # Sandboxed builders may not expose a writable disk device. A read-only HFS
  # hybrid remains directly mountable by Finder and keeps the same DMG UX.
  /bin/rm -f "$OUTPUT"
  /usr/bin/hdiutil makehybrid \
    -hfs \
    -hfs-volume-name "Codex 皮肤管理器" \
    -o "$OUTPUT" \
    "$DMG_ROOT" >/dev/null
fi

"$SCRIPT_DIR/verify-installer-dmg-macos.sh" "$OUTPUT"
SHA256="$(/usr/bin/shasum -a 256 "$OUTPUT" | /usr/bin/awk '{print $1}')"
/usr/bin/printf 'Created %s\nSHA-256 %s\n' "$OUTPUT" "$SHA256"
