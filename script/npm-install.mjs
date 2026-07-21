#!/usr/bin/env node

import {
  createHash,
  createPublicKey,
  verify as verifySignature,
} from "node:crypto";
import {
  access,
  mkdir,
  open,
  rename,
  rm,
  stat,
} from "node:fs/promises";
import { constants as fsConstants, realpathSync } from "node:fs";
import { platform as hostPlatform, tmpdir } from "node:os";
import { basename, join } from "node:path";
import { pathToFileURL } from "node:url";
import { execFileSync, spawnSync } from "node:child_process";

const CLI_VERSION = "1.7.2";
const DEFAULT_FEED_URL =
  "https://raw.githubusercontent.com/houyuhang915-sudo/Codex-Skin-Manager/main/updates/stable.json";
const PUBLIC_KEY = {
  kty: "OKP",
  crv: "Ed25519",
  x: "5_BSHZg9M_SVnRiUlMqF24Am-kprwLXYgDljQcFNOKc",
};
const MAX_METADATA_BYTES = 2 * 1024 * 1024;
const MAX_INSTALLER_BYTES = 512 * 1024 * 1024;

function fail(message) {
  const error = new Error(message);
  error.name = "CodexSkinInstallError";
  throw error;
}

function requireHTTPS(value, label) {
  let url;
  try {
    url = new URL(value);
  } catch {
    fail(`${label}地址格式无效`);
  }
  if (url.protocol !== "https:" || !url.hostname) fail(`${label}必须使用 HTTPS`);
  return url;
}

export function platformKey(platform = hostPlatform()) {
  if (platform === "darwin") return "macos";
  if (platform === "win32") return "windows";
  fail("Codex 桌面端安装器目前支持 macOS 和 Windows");
}

export function verifySignedFeed(feedData, signatureText) {
  if (!Buffer.isBuffer(feedData) || feedData.length === 0 || feedData.length > MAX_METADATA_BYTES) {
    fail("更新清单大小无效");
  }
  const normalizedSignature = String(signatureText).trim();
  const signature = Buffer.from(normalizedSignature, "base64");
  if (signature.length !== 64) fail("更新签名格式无效");
  const key = createPublicKey({ key: PUBLIC_KEY, format: "jwk" });
  if (!verifySignature(null, feedData, key, signature)) fail("更新清单签名校验失败");

  let feed;
  try {
    feed = JSON.parse(feedData.toString("utf8"));
  } catch {
    fail("更新清单不是有效 JSON");
  }
  if (feed?.schemaVersion !== 1 || feed?.channel !== "stable") {
    fail("更新清单版本不受支持");
  }
  if (!/^\d+\.\d+\.\d+$/.test(feed.version ?? "")) fail("更新版本号无效");
  return feed;
}

export function selectAsset(feed, platform = hostPlatform()) {
  const key = platformKey(platform);
  const asset = feed?.platforms?.[key];
  if (!asset) fail(`更新清单缺少 ${key} 安装包`);
  const url = requireHTTPS(asset.url, "安装包");
  if (!/^[a-f0-9]{64}$/.test(asset.sha256 ?? "")) fail("安装包 SHA-256 格式无效");
  if (!Number.isSafeInteger(asset.size) || asset.size <= 0 || asset.size > MAX_INSTALLER_BYTES) {
    fail("安装包大小无效");
  }
  return { ...asset, url: url.href, platform: key };
}

async function fetchBuffer(url, maximumBytes, label) {
  const response = await fetch(requireHTTPS(url, label), {
    redirect: "follow",
    headers: { "user-agent": `codex-skin-manager-npm/${CLI_VERSION}` },
    signal: AbortSignal.timeout(60_000),
  });
  if (!response.ok || response.url && new URL(response.url).protocol !== "https:") {
    fail(`${label}下载失败：HTTP ${response.status}`);
  }
  const data = Buffer.from(await response.arrayBuffer());
  if (data.length === 0 || data.length > maximumBytes) fail(`${label}大小无效`);
  return data;
}

export async function sha256File(path) {
  const handle = await open(path, "r");
  const hash = createHash("sha256");
  try {
    for await (const chunk of handle.readableWebStream()) hash.update(Buffer.from(chunk));
  } finally {
    await handle.close();
  }
  return hash.digest("hex");
}

async function installerIsValid(path, asset) {
  try {
    const information = await stat(path);
    if (!information.isFile() || information.size !== asset.size) return false;
    return await sha256File(path) === asset.sha256;
  } catch {
    return false;
  }
}

async function downloadInstaller(asset, version) {
  const url = new URL(asset.url);
  const filename = basename(url.pathname);
  if (!filename || filename === "." || filename === "..") fail("安装包文件名无效");
  const directory = join(tmpdir(), "codex-skin-manager", version);
  const destination = join(directory, filename);
  const partial = `${destination}.partial-${process.pid}`;
  await mkdir(directory, { recursive: true });

  if (await installerIsValid(destination, asset)) {
    console.log(`复用已校验安装包：${destination}`);
    return destination;
  }
  await rm(partial, { force: true });
  console.log(`正在下载 Codex 皮肤管理器 ${version}…`);
  const response = await fetch(asset.url, {
    redirect: "follow",
    headers: { "user-agent": `codex-skin-manager-npm/${CLI_VERSION}` },
    signal: AbortSignal.timeout(15 * 60_000),
  });
  if (!response.ok || !response.body || new URL(response.url).protocol !== "https:") {
    fail(`安装包下载失败：HTTP ${response.status}`);
  }

  const handle = await open(partial, "wx", 0o600);
  const hash = createHash("sha256");
  let received = 0;
  try {
    for await (const chunk of response.body) {
      const buffer = Buffer.from(chunk);
      received += buffer.length;
      if (received > asset.size || received > MAX_INSTALLER_BYTES) fail("安装包超过声明大小");
      hash.update(buffer);
      let offset = 0;
      while (offset < buffer.length) {
        const { bytesWritten } = await handle.write(buffer, offset, buffer.length - offset);
        if (bytesWritten <= 0) fail("写入安装包时没有取得进展");
        offset += bytesWritten;
      }
    }
  } catch (error) {
    await handle.close();
    await rm(partial, { force: true });
    throw error;
  }
  await handle.close();

  if (received !== asset.size) {
    await rm(partial, { force: true });
    fail(`安装包大小校验失败：收到 ${received}，应为 ${asset.size}`);
  }
  const digest = hash.digest("hex");
  if (digest !== asset.sha256) {
    await rm(partial, { force: true });
    fail("安装包 SHA-256 校验失败");
  }
  await rm(destination, { force: true });
  await rename(partial, destination);
  console.log(`下载与签名校验完成：${destination}`);
  return destination;
}

function mountMacInstaller(dmgPath) {
  const output = execFileSync("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", dmgPath], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  const mountPoint = output
    .split(/\r?\n/)
    .map((line) => line.split("\t").at(-1)?.trim())
    .findLast((value) => value?.startsWith("/Volumes/"));
  if (!mountPoint) fail("安装包已挂载，但没有找到挂载目录");
  return mountPoint;
}

async function launchMacInstaller(dmgPath) {
  const mountPoint = mountMacInstaller(dmgPath);
  try {
    const installer = join(mountPoint, "安装 Codex 皮肤管理器.app");
    await access(installer, fsConstants.R_OK);
    console.log("正在启动 macOS 一键安装器…");
    const result = spawnSync(
      "/usr/bin/open",
      ["-W", "-n", installer, "--args", "--automatic-update"],
      { stdio: "inherit" }
    );
    if (result.error) throw result.error;
    if (result.status !== 0) fail(`macOS 安装器退出代码：${result.status}`);
  } finally {
    spawnSync("/usr/bin/hdiutil", ["detach", mountPoint], { stdio: "ignore" });
  }
}

function launchWindowsInstaller(exePath, silent) {
  console.log(silent ? "正在静默安装 Windows 版本…" : "正在启动 Windows 一键安装器…");
  const result = spawnSync(exePath, silent ? ["/S"] : [], {
    stdio: "inherit",
    windowsHide: false,
  });
  if (result.error) throw result.error;
  if (result.status !== 0) fail(`Windows 安装器退出代码：${result.status}`);
}

async function readSignedFeed() {
  const feedURL = process.env.CODEX_SKIN_UPDATE_FEED_URL || DEFAULT_FEED_URL;
  const signatureURL = `${requireHTTPS(feedURL, "更新清单").href}.sig`;
  const [feedData, signatureData] = await Promise.all([
    fetchBuffer(feedURL, MAX_METADATA_BYTES, "更新清单"),
    fetchBuffer(signatureURL, 4096, "更新签名"),
  ]);
  return verifySignedFeed(feedData, signatureData.toString("utf8"));
}

function printHelp() {
  console.log(`Codex 皮肤管理器 npm 安装器 ${CLI_VERSION}

用法：
  codex-skin-manager install [--silent]
  codex-skin-manager --version

install 会验证 Ed25519 更新清单、安装包大小与 SHA-256，然后启动当前平台安装器。
--silent 仅在 Windows 使用，执行 NSIS 静默安装。`);
}

export async function main(argumentsList = process.argv.slice(2)) {
  const [command = "install", ...options] = argumentsList;
  if (command === "--help" || command === "-h" || command === "help") {
    printHelp();
    return;
  }
  if (command === "--version" || command === "-v") {
    console.log(CLI_VERSION);
    return;
  }
  if (command !== "install") fail(`未知命令：${command}`);
  const unknownOption = options.find((option) => option !== "--silent");
  if (unknownOption) fail(`未知参数：${unknownOption}`);

  const feed = await readSignedFeed();
  const asset = selectAsset(feed);
  const installer = await downloadInstaller(asset, feed.version);
  if (asset.platform === "macos") await launchMacInstaller(installer);
  else launchWindowsInstaller(installer, options.includes("--silent"));
  console.log(`Codex 皮肤管理器 ${feed.version} 安装流程已完成。`);
}

const entryURL = process.argv[1] ? pathToFileURL(realpathSync(process.argv[1])).href : "";
if (import.meta.url === entryURL) {
  main().catch((error) => {
    console.error(`Codex 皮肤管理器：${error.message}`);
    process.exitCode = 1;
  });
}
