# Codex Skin Manager

<p align="center">
  <a href="./README.md">中文</a> · <strong>English</strong>
</p>

<p align="center">
  A switchable, creatable, importable, and restorable theme system for Codex Desktop.<br>
  The native sidebar, conversations, project picker, and composer remain interactive.
</p>

<p align="center">
  <a href="https://github.com/Fei-Away/Codex-Dream-Skin/releases">Releases</a>
  ·
  <a href="./docs/theme-format.md">Theme format</a>
  ·
  <a href="./docs/platforms.md">Platforms</a>
</p>

> Unofficial and not affiliated with OpenAI. Themes are injected through loopback-only CDP. The project does not modify the official `.app`, `app.asar`, WindowsApps files, or code signatures.

## Showcase

<table>
  <tr>
    <th width="50%">Home</th>
    <th width="50%">Chat</th>
  </tr>
  <tr>
    <td><img src="docs/images/showcase/cartethyia-home.png" alt="Cartethyia theme home page"></td>
    <td><img src="docs/images/showcase/cartethyia-chat.png" alt="Cartethyia theme chat page"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><strong>Cartethyia · Sea Breeze</strong></td>
  </tr>
  <tr>
    <td><img src="docs/images/showcase/miku-home.png" alt="Hatsune Miku theme home page"></td>
    <td><img src="docs/images/showcase/miku-chat.png" alt="Hatsune Miku theme chat page"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><strong>Hatsune Miku</strong></td>
  </tr>
  <tr>
    <td><img src="docs/images/showcase/cyrene-home.png" alt="Cyrene theme home page"></td>
    <td><img src="docs/images/showcase/cyrene-chat.png" alt="Cyrene theme chat page"></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><strong>Cyrene · Star Sea</strong></td>
  </tr>
</table>

These images were captured from real Codex pages. Conversation content, task names, projects, and other sidebar details were hidden during capture while preserving the theme and native interface structure.

## Features

- 14 built-in appearances with the stock Codex theme pinned first
- Native macOS and Windows theme managers
- One-click switching and restoration
- In-app theme creation with adjustable horizontal crop focus
- Bundled Codex theme-creator Skill that generates and installs themes from chat
- Automatic `2400x800` background and `1200x400` preview generation
- Light/dark appearance, author, category, and palette controls
- Strict schema 2 folder import with field, PNG, aspect-ratio, size, and path validation
- Shared styling for home, chat, plugin, skill, sidebar, composer, menu, and notification surfaces
- Pet overlay remains visible across every theme switch

## Install

Download the platform package from [Releases](https://github.com/Fei-Away/Codex-Dream-Skin/releases).

### macOS

1. Open `Codex 皮肤管理器 1.5.0.dmg`.
2. Launch `安装 Codex 皮肤管理器.app`.
3. Click the install button. The manager opens after installation.

Requirements: macOS 14+, official Codex Desktop.

Installed locations:

```text
App: ~/Applications/Codex 皮肤管理器.app
Engine: ~/.codex/codex-dream-skin-studio
Themes: ~/Library/Application Support/CodexDreamSkinStudio/themes
```

### Windows

1. Codex may remain open.
2. Run `Codex-Skin-Manager-Setup-1.5.0.exe`.
3. Open `Codex 皮肤管理器` from the Start menu.

Starting with `1.4.1`, setup works while Codex is running. The current window remains open, and the theme takes effect when it is first applied.

Requirements: Windows 10/11, Microsoft Store Codex.

Installed locations:

```text
Engine: %LOCALAPPDATA%\CodexDreamSkin\engine-1.5.0
Themes: %LOCALAPPDATA%\CodexDreamSkin\themes
State and logs: %LOCALAPPDATA%\CodexDreamSkin
```

## Create And Import

Use **Create Theme** in the manager to select an image, adjust crop focus, enter metadata, choose light/dark mode, and set three palette colors.

The manager produces:

```text
my-theme/
├── theme.json
├── background.png
└── preview.png
```

Use **Import Theme** to install a folder with the same structure. The importer enforces schema 2, safe lowercase IDs, required `style` and `appearance` fields, real 3:1 PNG files, required colors, `avatarOverlay: "show"`, and protected built-in IDs. See [docs/theme-format.md](./docs/theme-format.md) for the complete schema, dimensions, color fields, and import contract.

### Create With The Codex Skill

The installer deploys [`codex-skin-theme-creator`](./skill/codex-skin-theme-creator) into the Codex Skill directory:

```text
macOS: ${CODEX_HOME:-~/.codex}/skills/codex-skin-theme-creator
Windows: %CODEX_HOME%\skills\codex-skin-theme-creator
```

The **Integration** page shows its status and can reinstall it. Example prompt:

```text
Create a dark star-sea Codex theme. Keep the character on the right
and the environment clear on the left. Name it "Star Sea Workspace".
```

The Skill can generate a new image or process a supplied image. It creates a `2400x800` background, `1200x400` preview, and schema 2 manifest, then atomically installs them into the user library. An open manager detects the new theme automatically. See the [Skill workflow](./skill/codex-skin-theme-creator/SKILL.md) for its complete behavior.

## Build From Source

```bash
git clone https://github.com/Fei-Away/Codex-Dream-Skin.git
cd Codex-Dream-Skin
```

macOS:

```bash
cd macos
npm test
./scripts/build-studio-app-macos.sh "$HOME/Desktop/Codex 皮肤管理器.app"
./scripts/build-installer-dmg-macos.sh "$HOME/Desktop/Codex 皮肤管理器 1.5.0.dmg"
```

Windows tests and manager:

```powershell
powershell -ExecutionPolicy Bypass -File windows\tests\run-tests.ps1
powershell -ExecutionPolicy Bypass -STA -File windows\scripts\theme-manager.ps1
```

Windows installer:

```bash
brew install nsis
windows/scripts/build-installer-windows.sh
```

Run the PowerShell, install, switch, restore, and uninstall checks on a real Windows machine before publishing a Windows release.

## Architecture

The manager starts the official Codex app with CDP bound to `127.0.0.1`, validates the Codex process and renderer target, then injects CSS, theme variables, and small decorative DOM elements. Native Codex controls remain in place.

## Repository Layout

```text
macos/                         macOS app, installer, runtime, and themes
windows/                       Windows manager, NSIS installer, runtime, and themes
skill/codex-skin-theme-creator Codex theme creator Skill
docs/images/showcase/          Sanitized README screenshots
docs/theme-format.md           Schema 2 theme contract
docs/platforms.md              Platform paths and capability matrix
script/                        Maintainer utilities
```

## Contributing

Read [AGENTS.md](./AGENTS.md) and the [theme format](./docs/theme-format.md). Run `cd macos && npm test` for macOS changes and `powershell -File windows/tests/run-tests.ps1` for Windows changes. Include home and chat screenshots for visual changes. Do not commit API keys, `auth.json`, private chats, customer data, or screenshots containing personal information.

## Sponsor

Thanks to [passion8.cc](https://passion8.cc/register?aff=TuPe) for sponsoring the project. Theme management and API provider configuration remain separate; this project does not rewrite API keys, base URLs, or provider settings.

## License

- Code: [MIT](./LICENSE)
- Asset records: [asset-provenance.md](./macos/references/asset-provenance.md)
- Codex and related marks belong to their respective owners
- Character themes are personal-use examples; verify the relevant content, character, and trademark rights before public or commercial redistribution
