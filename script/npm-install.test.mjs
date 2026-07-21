import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

import {
  platformKey,
  selectAsset,
  sha256File,
  verifySignedFeed,
} from "./npm-install.mjs";

const repositoryRoot = dirname(dirname(fileURLToPath(import.meta.url)));

test("committed stable feed verifies with the embedded Ed25519 public key", async () => {
  const feedData = await readFile(join(repositoryRoot, "updates/stable.json"));
  const signature = await readFile(join(repositoryRoot, "updates/stable.json.sig"), "utf8");
  const feed = verifySignedFeed(feedData, signature);
  assert.match(feed.version, /^\d+\.\d+\.\d+$/);
  assert.equal(selectAsset(feed, "darwin").platform, "macos");
  assert.equal(selectAsset(feed, "win32").platform, "windows");
});

test("changed feed is rejected", async () => {
  const feedData = await readFile(join(repositoryRoot, "updates/stable.json"));
  const signature = await readFile(join(repositoryRoot, "updates/stable.json.sig"), "utf8");
  const changed = Buffer.from(feedData);
  changed[changed.length - 2] ^= 1;
  assert.throws(() => verifySignedFeed(changed, signature), /签名校验失败/);
});

test("platform mapping rejects unsupported desktop platforms", () => {
  assert.equal(platformKey("darwin"), "macos");
  assert.equal(platformKey("win32"), "windows");
  assert.throws(() => platformKey("linux"), /支持 macOS 和 Windows/);
});

test("installer file hashing is deterministic", async () => {
  const root = await mkdtemp(join(tmpdir(), "codex-skin-npm-test-"));
  const fixture = join(root, "fixture.bin");
  try {
    await writeFile(fixture, "codex-skin-manager\n", "utf8");
    assert.equal(
      await sha256File(fixture),
      "8e2c1a2308c0c31561e41041e6bf16d1838a890fe748a42ee8e932f6b26f78fc"
    );
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
