import { loadConfig } from "./config.ts";
import { IpcClient, RpcCallError } from "./ipc/client.ts";
import { makeLogger } from "./log.ts";

/**
 * First runnable proof-of-life: connect to the shell (or fake-shell), complete the
 * versioned handshake, query permissions, draw a spotlight, and confirm the refusal
 * invariant by calling input.key and logging the typed REFUSED. Also logs any
 * pushed shell→core events. `--once` exits after one pass.
 */
async function main() {
  const cfg = loadConfig();
  const log = makeLogger(cfg.logLevel);
  const once = process.argv.includes("--once");

  log.info({ url: cfg.ipcUrl, source: cfg.source }, "agent-core starting");
  const client = new IpcClient({
    url: cfg.ipcUrl,
    token: cfg.ipcToken,
    coreVersion: "0.1.0",
    log,
    reconnect: !once,
  });

  client.on("workspace.frontmostChanged", (e) =>
    log.info({ app: e.appName, bundleId: e.bundleId }, "frontmost changed"),
  );
  client.on("possession.changed", (e) =>
    log.info({ holder: e.holder, cause: e.cause }, "possession changed"),
  );
  client.on("hardware.interrupt", (e) => log.warn({ kind: e.kind }, "hardware interrupt"));
  client.on("permission.status", (e) =>
    log.info({ permission: e.permission, status: e.status }, "permission changed"),
  );

  await client.connect();

  const perms = await client.call("permissions.query", {});
  log.info({ perms }, "permission status");

  const drawn = await client.call("overlay.draw", {
    items: [
      {
        kind: "spotlight",
        rect: { x: 120, y: 120, width: 400, height: 240 },
        caption: "Hello from agent-core",
      },
    ],
    ttlMs: 2000,
  });
  log.info({ drawn: drawn.drawn }, "overlay drawn");

  try {
    await client.call("input.key", { pid: process.pid, keys: "cmd+b" });
    log.error("input.key unexpectedly succeeded — the shell should refuse it");
  } catch (e) {
    if (e instanceof RpcCallError) {
      log.info(
        { code: e.code, reason: (e.data as { reason?: string } | undefined)?.reason },
        "input.key REFUSED (expected)",
      );
    } else {
      throw e;
    }
  }

  if (once) {
    client.close();
    return;
  }
  log.info("connected — press Ctrl-C to exit");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
