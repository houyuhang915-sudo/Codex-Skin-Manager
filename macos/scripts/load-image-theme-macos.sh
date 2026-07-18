#!/bin/bash

# Dynamically load one pure image as the active theme.
# Hot-applies when CDP is already open (fast).

set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/common-macos.sh"

IMAGE=""
THEME_NAME=""
FROM_LIBRARY=""
APPLY_NOW="true"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file) IMAGE="${2:-}"; shift 2 ;;
    --from-library) FROM_LIBRARY="${2:-}"; shift 2 ;;
    --name) THEME_NAME="${2:-}"; shift 2 ;;
    --no-apply) APPLY_NOW="false"; shift ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

ensure_state_root
IMAGES_DIR="$STATE_ROOT/images"
THEMES_ROOT="$STATE_ROOT/themes"
/bin/mkdir -p "$IMAGES_DIR" "$THEMES_ROOT" "$THEME_DIR"

if [ -n "$FROM_LIBRARY" ]; then
  IMAGE="$IMAGES_DIR/$FROM_LIBRARY"
fi

[ -n "$IMAGE" ] || fail "Pass --file <image> or --from-library <name-in-images-dir>"
[ -f "$IMAGE" ] || fail "Image not found: $IMAGE"

case "$IMAGE" in
  *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP|*.heic|*.HEIC|*.tif|*.tiff|*.TIF|*.TIFF) ;;
  *) fail "Unsupported image type: $IMAGE" ;;
esac

SOURCE_BYTES="$(/usr/bin/stat -f '%z' "$IMAGE")"
[ "$SOURCE_BYTES" -le 52428800 ] || fail "Image larger than 50 MB."

if [ -z "$THEME_NAME" ]; then
  base="$(/usr/bin/basename "$IMAGE")"
  THEME_NAME="${base%.*}"
fi
THEME_NAME="$(printf '%s' "$THEME_NAME" | /usr/bin/tr -d '\n' | /usr/bin/cut -c1-80)"
[ -n "$THEME_NAME" ] || THEME_NAME="我的主题"

theme_id="img-$(/bin/date '+%Y%m%d%H%M%S')-$$"

progress() {
  printf '%s\n' "$*" >&2
  /usr/bin/osascript -e "display notification \"$*\" with title \"Codex 皮肤管理器\"" >/dev/null 2>&1 || true
}

progress "正在生成标准主题包..."
"$SCRIPT_DIR/customize-theme-macos.sh" \
  --image "$IMAGE" \
  --name "$THEME_NAME" \
  --tagline "把喜欢的画面变成可交互的 Codex 工作台。" \
  --quote "MAKE SOMETHING WONDERFUL" \
  --accent "#E25563" \
  --secondary "#F3A8AF" \
  --highlight "#C93D4C" \
  --no-apply >/dev/null

ensure_node_runtime
theme_id="$("$NODE" -e '
  const value = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value.id || "")) process.exit(2);
  process.stdout.write(value.id);
' "$THEME_DIR/theme.json")"
lib_dir="$THEMES_ROOT/$theme_id"
temporary_lib="$THEMES_ROOT/.${theme_id}.installing.$$"
/bin/rm -rf "$temporary_lib"
/bin/mkdir -p "$temporary_lib"
/bin/cp -f \
  "$THEME_DIR/background.png" \
  "$THEME_DIR/preview.png" \
  "$THEME_DIR/theme.json" \
  "$temporary_lib/"
/bin/rm -rf "$lib_dir"
/bin/mv "$temporary_lib" "$lib_dir"
/bin/chmod 600 "$lib_dir/"* 2>/dev/null || true

dest_lib_img="$IMAGES_DIR/$(/usr/bin/basename "$IMAGE")"
src_dir="$(cd "$(dirname "$IMAGE")" && pwd -P)"
img_dir="$(cd "$IMAGES_DIR" && pwd -P)"
if [ "$src_dir/$(/usr/bin/basename "$IMAGE")" != "$img_dir/$(/usr/bin/basename "$IMAGE")" ]; then
  /bin/cp -f "$IMAGE" "$dest_lib_img" 2>/dev/null || true
fi

if [ "$APPLY_NOW" != "true" ]; then
  progress "Ready: ${THEME_NAME} (not applied)"
  exit 0
fi

PORT=9341
if [ -f "$STATE_PATH" ]; then
  saved="$(state_field port 2>/dev/null || true)"
  [ -n "${saved:-}" ] && PORT="$saved"
fi

progress "Hot reapply..."
if hot_reapply_theme "$PORT" 8000; then
  progress "Done: ${THEME_NAME}"
  exit 0
fi

progress "CDP not ready, full start..."
if "$SCRIPT_DIR/start-dream-skin-macos.sh" --port "$PORT" --restart-existing; then
  progress "Done: ${THEME_NAME}"
  exit 0
fi

/usr/bin/osascript -e 'display alert "Codex 皮肤管理器" message "图片已保存，但实时应用失败，请重新点击切换。"' >/dev/null 2>&1 || true
exit 1
