import { execFileSync } from "node:child_process";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.resolve(scriptDirectory, "..");
const outputDirectory = path.resolve(
  process.argv[2] ?? path.join(repositoryRoot, "docs/images/showcase")
);
const port = Number(process.env.CODEX_SKIN_CDP_PORT ?? "9341");
const switchScript = path.join(repositoryRoot, "macos/scripts/switch-theme-macos.sh");
const themes = [
  {
    id: "cartethyia-wuthering-waves",
    style: "cartethyia-wuthering-waves",
    filename: "cartethyia",
  },
  { id: "miku-dream-skin", style: "miku-stage", filename: "miku" },
  { id: "cyrene-star-rail", style: "cyrene-star-rail", filename: "cyrene" },
];
const activeThemeManifest = path.join(
  process.env.HOME,
  "Library/Application Support/CodexDreamSkinStudio/theme/theme.json"
);

class CdpSession {
  constructor(webSocketURL) {
    this.webSocket = new WebSocket(webSocketURL);
    this.nextID = 1;
    this.pending = new Map();
  }

  async open() {
    this.webSocket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      if (message.error) pending.reject(new Error(message.error.message));
      else pending.resolve(message.result);
    });
    await new Promise((resolve, reject) => {
      this.webSocket.addEventListener("open", resolve, { once: true });
      this.webSocket.addEventListener("error", reject, { once: true });
    });
  }

  send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = this.nextID++;
      this.pending.set(id, { resolve, reject });
      this.webSocket.send(JSON.stringify({ id, method, params }));
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
      awaitPromise: true,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.text ?? "Renderer evaluation failed");
    }
    return result.result.value;
  }

  close() {
    this.webSocket.close();
  }
}

async function findRendererTarget() {
  const response = await fetch(`http://127.0.0.1:${port}/json/list`);
  if (!response.ok) throw new Error(`CDP target list returned HTTP ${response.status}`);
  const targets = await response.json();
  const target = targets.find((candidate) => {
    if (candidate.type !== "page" || !candidate.webSocketDebuggerUrl) return false;
    if (!candidate.url.startsWith("app://-/")) return false;
    return !candidate.url.includes("initialRoute=%2Favatar-overlay");
  });
  if (!target) throw new Error("Codex renderer target was not found");
  const debuggerURL = new URL(target.webSocketDebuggerUrl);
  if (debuggerURL.hostname !== "127.0.0.1" || Number(debuggerURL.port) !== port) {
    throw new Error("Codex renderer exposed a non-loopback debugger URL");
  }
  return target;
}

async function waitFor(session, expression, timeoutMilliseconds = 15_000) {
  const deadline = Date.now() + timeoutMilliseconds;
  while (Date.now() < deadline) {
    if (await session.evaluate(`Boolean(${expression})`)) return;
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  throw new Error(`Timed out waiting for renderer state: ${expression}`);
}

async function applyTheme(session, themeID, themeStyle = themeID) {
  execFileSync("/bin/bash", [switchScript, "--id", themeID], {
    cwd: repositoryRoot,
    stdio: "ignore",
  });
  await waitFor(
    session,
    `document.documentElement.dataset.dreamThemeStyle === ${JSON.stringify(themeStyle)}`
  );
  await new Promise((resolve) => setTimeout(resolve, 700));
}

async function navigateHome(session) {
  const clicked = await session.evaluate(`(() => {
    const button = [...document.querySelectorAll("button")]
      .find((candidate) => candidate.textContent.trim() === "新建任务");
    if (!button) return false;
    button.click();
    return true;
  })()`);
  if (!clicked) throw new Error("The New task button was not found");
  await waitFor(
    session,
    `document.querySelector("main.main-surface")?.classList.contains("dream-skin-home-shell")`
  );
  await new Promise((resolve) => setTimeout(resolve, 700));
}

async function navigateThread(session, threadID) {
  const clicked = await session.evaluate(`(() => {
    const threadID = ${JSON.stringify(threadID)};
    const row = [...document.querySelectorAll("[data-app-action-sidebar-thread-id]")]
      .find((candidate) => candidate.getAttribute("data-app-action-sidebar-thread-id") === threadID);
    if (!row) return false;
    row.click();
    return true;
  })()`);
  if (!clicked) throw new Error("The source task was not found in the sidebar");
  await waitFor(
    session,
    `document.querySelector(".thread-scroll-container") &&
      document.querySelector("[data-codex-composer-root]")`
  );
  await new Promise((resolve) => setTimeout(resolve, 700));
}

async function installPrivacyMask(session, hideConversation) {
  await session.evaluate(`(() => {
    document.getElementById("codex-readme-privacy-style")?.remove();
    document.getElementById("codex-readme-privacy-mask")?.remove();

    const style = document.createElement("style");
    style.id = "codex-readme-privacy-style";
    style.textContent = \`
      [data-app-action-sidebar-scroll] {
        visibility: hidden !important;
      }
      main.main-surface > header * {
        visibility: hidden !important;
      }
      ${
        hideConversation
          ? `[data-mcp-app-portal-target] {
        visibility: hidden !important;
      }
      [data-above-composer-portal] {
        visibility: hidden !important;
      }`
          : ""
      }
    \`;
    document.head.appendChild(style);

    const sidebar = document.querySelector("aside.app-shell-left-panel");
    const scroll = document.querySelector("[data-app-action-sidebar-scroll]");
    if (!sidebar || !scroll) throw new Error("Sidebar privacy region was not found");
    const sidebarRect = sidebar.getBoundingClientRect();
    const scrollRect = scroll.getBoundingClientRect();
    const mask = document.createElement("div");
    mask.id = "codex-readme-privacy-mask";
    mask.setAttribute("aria-hidden", "true");
    Object.assign(mask.style, {
      position: "fixed",
      left: "8px",
      top: Math.max(122, scrollRect.top + 4) + "px",
      width: Math.max(180, sidebarRect.width - 16) + "px",
      height: Math.max(180, innerHeight - Math.max(122, scrollRect.top + 4) - 14) + "px",
      zIndex: "2147483000",
      pointerEvents: "none",
      boxSizing: "border-box",
      padding: "18px 16px",
      borderRadius: "8px",
      border: "1px solid var(--ds-line, rgba(127,127,127,.18))",
      background: "var(--ds-panel, rgba(30,30,30,.96))",
      boxShadow: "0 14px 38px rgba(0,0,0,.12)",
      overflow: "hidden",
    });

    const widths = [42, 74, 58, 82, 64, 48, 78, 55, 70, 44, 80, 62];
    widths.forEach((width, index) => {
      const row = document.createElement("div");
      Object.assign(row.style, {
        width: width + "%",
        height: index % 4 === 0 ? "11px" : "9px",
        marginTop: index === 0 ? "0" : index % 4 === 0 ? "24px" : "15px",
        borderRadius: "4px",
        background: index % 4 === 0
          ? "var(--ds-green, rgba(127,127,127,.36))"
          : "var(--ds-line, rgba(127,127,127,.22))",
        opacity: index % 4 === 0 ? ".42" : ".68",
      });
      mask.appendChild(row);
    });
    document.body.appendChild(mask);
    return true;
  })()`);
  await new Promise((resolve) => setTimeout(resolve, 250));
}

async function removePrivacyMask(session) {
  await session.evaluate(`(() => {
    document.getElementById("codex-readme-privacy-style")?.remove();
    document.getElementById("codex-readme-privacy-mask")?.remove();
  })()`);
}

async function capture(session, outputPath) {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await session.send("Input.dispatchKeyEvent", {
    type: "keyDown",
    key: "Escape",
    code: "Escape",
    windowsVirtualKeyCode: 27,
  });
  await session.send("Input.dispatchKeyEvent", {
    type: "keyUp",
    key: "Escape",
    code: "Escape",
    windowsVirtualKeyCode: 27,
  });
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseMoved",
    x: 1040,
    y: 520,
    button: "none",
  });
  await new Promise((resolve) => setTimeout(resolve, 250));
  const screenshot = await session.send("Page.captureScreenshot", {
    format: "png",
    fromSurface: true,
    captureBeyondViewport: false,
  });
  await fs.writeFile(outputPath, Buffer.from(screenshot.data, "base64"));
}

const target = await findRendererTarget();
const session = new CdpSession(target.webSocketDebuggerUrl);
await session.open();

const originalTheme = JSON.parse(await fs.readFile(activeThemeManifest, "utf8"));
const originalThreadID = await session.evaluate(
  `document.querySelector("[data-app-action-sidebar-thread-active=true]")
    ?.getAttribute("data-app-action-sidebar-thread-id") || ""`
);
if (!originalThreadID) throw new Error("Open a Codex task before capturing the showcase");

try {
  for (const theme of themes) {
    await removePrivacyMask(session);
    await applyTheme(session, theme.id, theme.style);
    await navigateHome(session);
    await installPrivacyMask(session, false);
    await capture(session, path.join(outputDirectory, `${theme.filename}-home.png`));

    await removePrivacyMask(session);
    await navigateThread(session, originalThreadID);
    await installPrivacyMask(session, true);
    await capture(session, path.join(outputDirectory, `${theme.filename}-chat.png`));
  }
} finally {
  await removePrivacyMask(session);
  await applyTheme(session, originalTheme.id, originalTheme.style);
  await navigateThread(session, originalThreadID).catch(() => {});
  session.close();
}

process.stdout.write(`Created sanitized README screenshots in ${outputDirectory}\n`);
