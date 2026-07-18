# Schema 2 主题规范

## 标准目录

```text
<theme-id>/
├── theme.json
├── background.png
└── preview.png
```

`background.png` 固定输出为 `2400x800`，`preview.png` 固定输出为 `1200x400`。两者均为精确 3:1 PNG。

## 创建参数

| 参数 | 要求 |
|---|---|
| `id` | 3–64 位，小写字母、数字、连字符，不能使用管理器内置 ID |
| `name` | 1–80 字符 |
| `description` | 最多 180 字符 |
| `appearance` | `light` 或 `dark` |
| `accent` / `secondary` / `highlight` | 六位十六进制颜色 |
| `focus` | 0–100，表示超宽源图的横向裁切焦点 |

## 固定字段

生成器固定写入：

```json
{
  "schemaVersion": 2,
  "style": "<theme-id>",
  "avatarOverlay": "show",
  "image": "background.png",
  "preview": "preview.png"
}
```

自定义主题不得声明 `mode: "original"`，也不得使用 `taskImage`。颜色对象必须包含 `background`、`panel`、`panelAlt`、`accent`、`accentAlt`、`secondary`、`highlight`、`text`、`muted` 和 `line`。

## 本机主题库

- macOS：`~/Library/Application Support/CodexDreamSkinStudio/themes`
- Windows：`%LOCALAPPDATA%\CodexDreamSkin\themes`

脚本先在临时目录生成并完整校验，再原子移动到用户主题库。相同自定义 ID 只有传入 `--replace` 才会替换。
