import { access } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = path.dirname(fileURLToPath(import.meta.url));
const input = process.argv.slice(2);

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

async function firstExecutable(candidates) {
  for (const candidate of candidates.filter(Boolean)) {
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Continue through the manager's supported install locations.
    }
  }
  return null;
}

function relay(result, label) {
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) fail(`${label}：${result.error.message}`);
  if (result.status !== 0) process.exit(result.status ?? 1);
}

if (input.includes("--help")) {
  process.stdout.write(
    "Usage: node create-theme.mjs --image PATH --id ID --name NAME " +
    "[--appearance light|dark] [--focus 0..100] [--replace]\n"
  );
  process.exit(0);
}

if (process.platform === "darwin") {
  const cli = await firstExecutable([
    process.env.CODEX_SKIN_THEME_CLI,
    path.join(
      os.homedir(),
      "Applications",
      "Codex 皮肤管理器.app",
      "Contents",
      "Resources",
      "Tools",
      "CodexThemeCreator"
    ),
    path.join(
      os.homedir(),
      "Desktop",
      "Codex 皮肤管理器.app",
      "Contents",
      "Resources",
      "Tools",
      "CodexThemeCreator"
    ),
    "/Applications/Codex 皮肤管理器.app/Contents/Resources/Tools/CodexThemeCreator",
  ]);
  if (!cli) {
    fail("未找到 Codex 皮肤管理器主题创建组件，请在管理器中重新安装主题创建 Skill");
  }
  relay(spawnSync(cli, input, { encoding: "utf8" }), "启动 macOS 主题创建器失败");
} else if (process.platform === "win32") {
  const script = path.join(here, "create-theme-windows.ps1");
  const powershell = process.env.SystemRoot
    ? path.join(process.env.SystemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
    : "powershell.exe";
  const parameterNames = new Map([
    ["--image", "-Image"],
    ["--id", "-Id"],
    ["--name", "-Name"],
    ["--author", "-Author"],
    ["--description", "-Description"],
    ["--category", "-Category"],
    ["--appearance", "-Appearance"],
    ["--accent", "-Accent"],
    ["--secondary", "-Secondary"],
    ["--highlight", "-Highlight"],
    ["--focus", "-Focus"],
    ["--themes-root", "-ThemesRoot"],
    ["--replace", "-Replace"],
  ]);
  const windowsInput = input.map((argument) => parameterNames.get(argument) ?? argument);
  relay(
    spawnSync(
      powershell,
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script, ...windowsInput],
      { encoding: "utf8" }
    ),
    "启动 Windows 主题创建器失败"
  );
} else {
  fail(`当前平台暂未集成 Codex 皮肤管理器：${process.platform}`);
}
