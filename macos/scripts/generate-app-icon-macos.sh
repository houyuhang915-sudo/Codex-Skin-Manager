#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

PNG_OUTPUT="${1:-$PROJECT_ROOT/assets/DreamSkinAppIcon.png}"
ICNS_OUTPUT="${2:-$PROJECT_ROOT/assets/DreamSkinAppIcon.icns}"
SOURCE="$SCRIPT_DIR/generate-app-icon-macos.swift"
TMP="$(/usr/bin/mktemp -d /tmp/codex-dream-skin-icon.XXXXXX)"
ICONSET="$TMP/DreamSkinAppIcon.iconset"
trap '/bin/rm -rf "$TMP"' EXIT

/bin/mkdir -p "$(dirname "$PNG_OUTPUT")" "$(dirname "$ICNS_OUTPUT")" "$ICONSET"
/usr/bin/xcrun swift "$SOURCE" "$PNG_OUTPUT"

resize() {
  local pixels="$1"
  local name="$2"
  /usr/bin/sips -z "$pixels" "$pixels" "$PNG_OUTPUT" --out "$ICONSET/$name" >/dev/null
}

resize 16 icon_16x16.png
resize 32 icon_16x16@2x.png
resize 32 icon_32x32.png
resize 64 icon_32x32@2x.png
resize 128 icon_128x128.png
resize 256 icon_128x128@2x.png
resize 256 icon_256x256.png
resize 512 icon_256x256@2x.png
resize 512 icon_512x512.png
resize 1024 icon_512x512@2x.png
/usr/bin/iconutil -c icns "$ICONSET" -o "$ICNS_OUTPUT"

/usr/bin/printf 'Generated %s and %s.\n' "$PNG_OUTPUT" "$ICNS_OUTPUT"
