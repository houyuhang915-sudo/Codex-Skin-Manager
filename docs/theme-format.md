# Dream Skin 主题格式

Codex 皮肤管理器使用 schema 2 单主图主题。图片只负责场景背景，Codex 原生 DOM 继续负责侧栏、标题、列表、对话、项目选择器和输入器。

## 目录结构

```text
<theme-id>/
├── theme.json
├── background.png
└── preview.png
```

导入时只读取和复制这三个文件。

## 文件限制

| 文件 | 要求 |
|---|---|
| `theme.json` | UTF-8 JSON 对象，不超过 256 KiB |
| `background.png` | 真实 PNG、精确 3:1、`1200x400` 到 `12000x4000`、不超过 30 MiB |
| `preview.png` | 真实 PNG、精确 3:1、`600x200` 到 `6000x2000`、不超过 10 MiB |

Studio 创建主题时固定输出：

- `background.png`：`2400x800`
- `preview.png`：`1200x400`
- `theme.json`：schema 2、UTF-8、无额外图片字段

主题文件夹和三个标准文件均需为普通文件，不接受符号链接。

## ID 规则

`id` 长度为 3 到 64，只使用小写字母、数字和连字符：

```text
^[a-z0-9]+(?:-[a-z0-9]+)*$
```

有效：`my-theme`、`rem-rezero`、`studio-2026`

无效：`My Theme`、`../theme`、`主题-a`

内置主题 ID 由管理器保护。导入相同 ID 的自定义主题时，软件会先确认再替换。

## 字段

| 字段 | 类型 | 必需 | 说明 |
|---|---|:---:|---|
| `schemaVersion` | number | 是 | 固定为 `2` |
| `id` | string | 是 | 符合上述 ID 规则 |
| `name` | string | 是 | 显示名称，最多 80 字符 |
| `author` | string | 否 | 作者或主题维护者 |
| `description` | string | 否 | 主题描述，Studio 最多 180 字符 |
| `category` | string | 否 | 例如 `自定义`、`动漫`、`角色` |
| `style` | string | 是 | CSS 风格标识；自定义主题通常与 `id` 相同 |
| `avatarOverlay` | string | 是 | 固定为 `show`，保证宠物层持续显示 |
| `appearance` | string | 是 | `auto`、`light` 或 `dark` |
| `brandSubtitle` | string | 否 | 首页品牌副标题 |
| `tagline` | string | 否 | 首页主题文案 |
| `projectPrefix` | string | 否 | 项目前缀 |
| `projectLabel` | string | 否 | 项目选择器标签 |
| `statusText` | string | 否 | 主题状态文字 |
| `quote` | string | 否 | 装饰短句 |
| `image` | string | 是 | 固定为 `background.png` |
| `preview` | string | 是 | 固定为 `preview.png` |
| `colors` | object | 是 | 基础主题色 |
| `colorsLight` | object | 否 | `appearance: auto` 时的浅色覆盖 |
| `colorsDark` | object | 否 | `appearance: auto` 时的暗色覆盖 |

`mode: "original"` 只保留给内置的 `codex-default`，自定义主题不可使用。schema 2 不使用 `taskImage`。

## colors

`colors` 必须包含以下键：

| 键 | 用途 |
|---|---|
| `background` | 主背景色 |
| `panel` | 侧栏和主要表面 |
| `panelAlt` | 次级表面 |
| `accent` | 主要操作色 |
| `accentAlt` | 强调色变体 |
| `secondary` | 辅助色 |
| `highlight` | 点缀色 |
| `text` | 主文字色 |
| `muted` | 次要文字色 |
| `line` | 边框色，可使用 `rgba(...)` |

除 `line` 外建议使用六位十六进制颜色。

## 完整示例

```json
{
  "schemaVersion": 2,
  "id": "my-theme",
  "name": "我的主题",
  "author": "Your Name",
  "description": "清爽的个人工作主题。",
  "category": "自定义",
  "style": "my-theme",
  "avatarOverlay": "show",
  "appearance": "light",
  "brandSubtitle": "CUSTOM THEME",
  "tagline": "让喜欢的画面陪你完成今天的工作。",
  "projectPrefix": "我的主题 · ",
  "projectLabel": "选择项目",
  "statusText": "CUSTOM THEME ONLINE",
  "quote": "我的主题 · 专注创作",
  "image": "background.png",
  "preview": "preview.png",
  "colors": {
    "background": "#f4f7f9",
    "panel": "#ffffff",
    "panelAlt": "#edf3f6",
    "accent": "#24a777",
    "accentAlt": "#24a777",
    "secondary": "#579bd7",
    "highlight": "#f2c14e",
    "text": "#25313a",
    "muted": "#687783",
    "line": "rgba(36, 167, 119, .28)"
  }
}
```

## 软件内创建

macOS 和 Windows 管理器都提供“创建主题”：

1. 选择源图片。
2. 用横向焦点控制裁切位置。
3. 填写名称、ID、作者、描述和分类。
4. 选择浅色或暗色并设置三组主色。
5. 创建后自动写入本机主题库。

生成器会从源图分别渲染主图和预览图，不使用伪 UI 截图。

安装器还会部署 `codex-skin-theme-creator` Skill。Skill 使用相同的创建核心、字段默认值、图片尺寸、内置 ID 保护和原子安装流程。通过对话创建完成后，主题直接写入上述用户主题库；已打开的管理器会监测主题库并自动刷新。

## 导入校验

两个平台的导入器会检查：

- 文件夹、清单和图片均为普通文件
- 清单大小、schema、ID、标准文件名和必需颜色
- `avatarOverlay == "show"`
- 不存在 `taskImage`
- PNG 文件头、文件大小、像素尺寸和精确 3:1 比例
- 目标目录由合法 ID 构造，不允许目录越界

导入只安装标准三文件，主题包内其他文件不会进入运行目录。

## 设计规范

- 主体面部或视觉中心建议位于横向 `55%–62%`
- 左侧保留真实场景细节，不预叠白雾、黑雾、文字底板或界面截图
- 首页、聊天页、插件页和技能页复用同一张 `background.png`
- 聊天页背景统一使用 `var(--dream-skin-art) 72% center / cover no-repeat`
- 原生正文、搜索框、列表、菜单和输入器必须保持可交互
- 宠物层必须保持显示

内置主题由 `macos/tests/run-tests.sh` 和 `windows/tests/run-tests.ps1` 共同校验。
