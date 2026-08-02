import { IPC_PATH } from "@aitutor/protocol";
import { IpcClient, RpcCallError } from "../src/ipc/client.ts";
import { makeLogger } from "../src/log.ts";
import { startFakeShell } from "./fake-shell.ts";

/**
 * One-shot, self-contained round-trip: starts the fake shell in-process, runs the
 * full client flow, prints RTTs, exits 0. This is `make demo` and the CI smoke —
 * no external process, no ports to coordinate.
 */
async function demo() {
  const log = makeLogger(process.env.LOG_LEVEL ?? "info");
  const shell = await startFakeShell({ port: 0, emitEvents: true });
  const client = new IpcClient({
    url: `ws://127.0.0.1:${shell.port}${IPC_PATH}`,
    token: shell.token,
    coreVersion: "0.1.0",
    log,
    reconnect: false,
  });

  client.on("workspace.frontmostChanged", (e) =>
    log.info({ app: e.appName }, "← event: frontmost changed"),
  );

  await client.connect();

  const t0 = performance.now();
  const pong = await client.call("shell.ping", { nonce: "demo" });
  log.info({ rttMs: +(performance.now() - t0).toFixed(2), nonce: pong.nonce }, "ping round-trip");

  const perms = await client.call("permissions.query", {});
  log.info({ perms }, "permissions");

  const drawn = await client.call("overlay.draw", {
    items: [
      { kind: "spotlight", rect: { x: 120, y: 120, width: 400, height: 240 }, caption: "demo" },
    ],
  });
  log.info({ drawn: drawn.drawn }, "overlay.draw ack");

  try {
    await client.call("input.key", { pid: 1, keys: "cmd+b" });
    throw new Error("input.key should have been REFUSED");
  } catch (e) {
    if (!(e instanceof RpcCallError) || e.code !== -32000) throw e;
    log.info(
      { reason: (e.data as { reason?: string }).reason },
      "input.key REFUSED (invariant holds)",
    );
  }

  // let the pushed event land
  await new Promise((r) => setTimeout(r, 50));
  client.close();
  await shell.close();
  log.info("demo OK");
}

demo().catch((err) => {
  console.error(err);
  process.exit(1);
});
