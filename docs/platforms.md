# 平台对照

## 运行模型（两边相同）

```text
用户本机主题工具
    │  启动官方 Codex + 本机 CDP
    ▼
官方 Codex Desktop（不改 asar / 签名）
    │  注入 CSS + 装饰 DOM
    ▼
仍用原生侧栏 / 输入框 / 建议卡
```

## 路径速查

### macOS

| 用途 | 路径 |
|------|------|
| 源码（本整理包） | `Codex-Dream-Skin/macos/` |
| 安装后引擎 | `~/.codex/codex-dream-skin-studio` |
| 状态 / 日志 | `~/Library/Application Support/CodexDreamSkinStudio` |
| 主题库 | `~/Library/Application Support/CodexDreamSkinStudio/themes` |
| 主题创建 Skill | `${CODEX_HOME:-~/.codex}/skills/codex-skin-theme-creator` |
| Codex 配置 | `~/.codex/config.toml`（仅外观相关项可能被改，可恢复） |

### Windows

| 用途 | 路径 |
|------|------|
| 源码（本整理包） | `Codex-Dream-Skin/windows/` |
| 安装后引擎 | `%LOCALAPPDATA%\CodexDreamSkin\engine-<version>` |
| 当前主题 | `%LOCALAPPDATA%\CodexDreamSkin\theme` |
| 主题库 | `%LOCALAPPDATA%\CodexDreamSkin\themes` |
| 主题创建 Skill | `%CODEX_HOME%\skills\codex-skin-theme-creator`，默认 `%USERPROFILE%\.codex\skills\...` |
| 状态 / 日志 | `%LOCALAPPDATA%\CodexDreamSkin` |
| Codex 配置 | `%USERPROFILE%\.codex\config.toml` |
| 默认 CDP 端口 | 首选 `9335`，冲突时自动选空闲口（Mac 包默认从 `9341` 起） |

## 能力矩阵

| 功能 | macOS | Windows |
|------|:-----:|:-------:|
| 安装脚本 | ✅ | ✅ |
| 启动 + 注入 | ✅ | ✅ |
| 一键恢复 | ✅ | ✅ |
| 实机 verify / 截图 | ✅ | ✅ |
| 内置主题一键切换 | ✅ | ✅ |
| 图形主题管理器 | ✅ | ✅ |
| 后台常驻与快速切换 | ✅ 菜单栏 | ✅ 系统托盘 |
| 软件内创建主题 | ✅ | ✅ |
| Skill 对话创建并自动入库 | ✅ | ✅ |
| schema 2 严格导入 | ✅ | ✅ |
| 横向裁切焦点 | ✅ | ✅ |
| 官方签名校验 | ✅ | Store 签名类型 + 包身份 |
| 一键安装包 | ✅ DMG | ✅ NSIS EXE |

## 不要放进这个目录的东西

- API Key、`.codex/auth.json`
- 中转站密钥、服务器私钥
- 含客户隐私的实机截图（若要公开）
