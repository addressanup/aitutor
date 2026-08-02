// Zero-dependency smoke client for the running shell (Node >=22 built-in WebSocket).
// Reads the shell's ipc.json handoff, authenticates, prints the permission table,
// then draws a 2-second spotlight. This is `make shell-smoke`.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const handoffPath = join(homedir(), "Library", "Application Support", "TutorShell", "ipc.json");
let handoff;
try {
  handoff = JSON.parse(readFileSync(handoffPath, "utf8"));
} catch {
  console.error(`No handoff file at ${handoffPath}. Is the shell running? Try: make shell-run`);
  process.exit(1);
}

const url = `ws://127.0.0.1:${handoff.port}/ipc`;
const ws = new WebSocket(url);
let id = 0;
const pending = new Map();

function call(method, params) {
  const rid = `c-${++id}`;
  ws.send(JSON.stringify({ jsonrpc: "2.0", id: rid, method, params }));
  return new Promise((resolve, reject) => pending.set(rid, { resolve, reject }));
}

ws.addEventListener("message", (ev) => {
  const msg = JSON.parse(ev.data);
  if (!msg.id || !pending.has(msg.id)) return;
  const p = pending.get(msg.id);
  pending.delete(msg.id);
  if (msg.error) p.reject(new Error(`${msg.error.code}: ${msg.error.message}`));
  else p.resolve(msg.result);
});

ws.addEventListener("open", async () => {
  try {
    const hello = await call("session.hello", {
      protocolMin: "0.1.0",
      protocolMax: "0.1.0",
      coreVersion: "smoke",
      token: handoff.token,
    });
    console.log(`handshake ok — protocol ${hello.protocolVersion}, shell ${hello.shellVersion}\n`);

    const perms = await call("permissions.query", {});
    console.log("permissions:");
    for (const [k, v] of Object.entries(perms)) console.log(`  ${k.padEnd(18)} ${v}`);

    const drawn = await call("overlay.draw", {
      items: [{ kind: "spotlight", rect: { x: 200, y: 200, width: 480, height: 300 }, caption: "smoke test — hello" }],
      ttlMs: 2000,
    });
    console.log(`\noverlay.draw drew ${drawn.drawn} spotlight(s) — watch your screen for 2s.`);

    setTimeout(() => {
      ws.close();
      process.exit(0);
    }, 2300);
  } catch (e) {
    console.error("smoke failed:", e.message);
    process.exit(1);
  }
});

ws.addEventListener("error", (e) => {
  console.error("connection error:", e.message ?? e);
  process.exit(1);
});
