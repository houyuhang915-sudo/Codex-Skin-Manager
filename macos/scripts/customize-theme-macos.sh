#!/bin/bash

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

IMAGE=""
THEME_NAME=""
TAGLINE=""
QUOTE=""
ACCENT="#7cff46"
SECONDARY="#36d7e8"
HIGHLIGHT="#642a8c"
APPLY_NOW="true"
RESET_DEMO="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image) IMAGE="${2:-}"; shift 2 ;;
    --name) THEME_NAME="${2:-}"; shift 2 ;;
    --tagline) TAGLINE="${2:-}"; shift 2 ;;
    --quote) QUOTE="${2:-}"; shift 2 ;;
    --accent) ACCENT="${2:-}"; shift 2 ;;
    --secondary) SECONDARY="${2:-}"; shift 2 ;;
    --highlight) HIGHLIGHT="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    --reset-demo) RESET_DEMO="true"; shift ;;
    *) fail "Unknown customize argument: $1" ;;
  esac
done

discover_codex_app
require_macos_runtime
ensure_state_root

if [ "$RESET_DEMO" = "true" ]; then
  "$NODE" "$SCRIPT_DIR/write-theme.mjs" reset-demo --output-dir "$THEME_DIR"
else
  if [ -z "$IMAGE" ]; then
    IMAGE="$(/usr/bin/osascript -e 'POSIX path of (choose file with prompt "选择一张主题图片（建议横向、宽度 2000px 以上）" of type {"public.image"})')" \
      || fail "Image selection was cancelled."
  fi
  [ -f "$IMAGE" ] || fail "Selected image does not exist: $IMAGE"
  SOURCE_BYTES="$(/usr/bin/stat -f '%z' "$IMAGE")"
  [ "$SOURCE_BYTES" -le 52428800 ] || fail "Selected image is larger than 50 MB. Choose a smaller file."

  if [ -z "$THEME_NAME" ]; then
    THEME_NAME="$(/usr/bin/osascript -e 'text returned of (display dialog "给这套主题起个名字" default answer "我的 Codex 主题" buttons {"取消", "继续"} default button "继续")')" \
      || fail "Theme setup was cancelled."
  fi
  if [ -z "$TAGLINE" ]; then TAGLINE="把喜欢的画面变成可交互的 Codex 工作台。"; fi
  if [ -z "$QUOTE" ]; then QUOTE="MAKE SOMETHING WONDERFUL"; fi

  /bin/mkdir -p "$THEME_DIR"
  /bin/chmod 700 "$THEME_DIR"
  image_name="background.png"
  preview_name="preview.png"
  stage="$THEME_DIR/.background-stage.$$.png"
  temporary="$THEME_DIR/.background.$$.png"
  preview_temporary="$THEME_DIR/.preview.$$.png"
  prepared="$THEME_DIR/$image_name"
  preview_prepared="$THEME_DIR/$preview_name"
  cleanup_temporary() { /bin/rm -f "$stage" "$temporary" "$preview_temporary"; }
  trap cleanup_temporary EXIT
  SOURCE_WIDTH="$(/usr/bin/sips -g pixelWidth "$IMAGE" 2>/dev/null | /usr/bin/awk '/pixelWidth/{print $2}')"
  SOURCE_HEIGHT="$(/usr/bin/sips -g pixelHeight "$IMAGE" 2>/dev/null | /usr/bin/awk '/pixelHeight/{print $2}')"
  case "$SOURCE_WIDTH:$SOURCE_HEIGHT" in
    *[!0-9:]*|:*|*:) fail "macOS could not read the selected image dimensions." ;;
  esac
  [ "$SOURCE_WIDTH" -gt 0 ] && [ "$SOURCE_HEIGHT" -gt 0 ] \
    || fail "The selected image dimensions are invalid."
  if [ "$SOURCE_WIDTH" -gt $((SOURCE_HEIGHT * 3)) ]; then
    /usr/bin/sips -s format png --resampleHeight 800 "$IMAGE" --out "$stage" >/dev/null
  else
    /usr/bin/sips -s format png --resampleWidth 2400 "$IMAGE" --out "$stage" >/dev/null
  fi
  /usr/bin/sips -s format png --cropToHeightWidth 800 2400 "$stage" --out "$temporary" >/dev/null \
    || fail "macOS could not prepare the 3:1 theme image. Use PNG, JPEG, HEIC, TIFF, or WebP."
  /usr/bin/sips -s format png --resampleHeightWidth 400 1200 "$temporary" --out "$preview_temporary" >/dev/null \
    || fail "macOS could not prepare preview.png."
  [ -s "$temporary" ] || fail "The converted image is empty."
  PREPARED_BYTES="$(/usr/bin/stat -f '%z' "$temporary")"
  [ "$PREPARED_BYTES" -le 16777216 ] || fail "The prepared image is larger than 16 MB. Choose a simpler or smaller image."
  /bin/mv -f "$temporary" "$prepared"
  /bin/mv -f "$preview_temporary" "$preview_prepared"
  /bin/chmod 600 "$prepared"
  /bin/chmod 600 "$preview_prepared"

  "$NODE" "$SCRIPT_DIR/write-theme.mjs" custom \
    --output-dir "$THEME_DIR" --image "$image_name" \
    --name "$THEME_NAME" --tagline "$TAGLINE" --quote "$QUOTE" \
    --accent "$ACCENT" --secondary "$SECONDARY" --highlight "$HIGHLIGHT"
  /usr/bin/find "$THEME_DIR" -maxdepth 1 -type f \
    ! -name 'background.png' ! -name 'preview.png' ! -name 'theme.json' -delete
  trap - EXIT
fi

if [ "$APPLY_NOW" = "true" ]; then
  "$SCRIPT_DIR/start-dream-skin-macos.sh" --port 9341 --prompt-restart
fi

printf 'Codex 皮肤管理器主题已准备完成。\n'
