import { IPC_PATH } from "@aitutor/protocol";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { type FakeShellHandle, startFakeShell } from "../../tools/fake-shell.ts";
import { makeLogger } from "../log.ts";
import { IpcClient, RpcCallError } from "./client.ts";

const log = makeLogger("silent");
let shell: FakeShellHandle;

function connect(token: string) {
  const client = new IpcClient({
    url: `ws://127.0.0.1:${shell.port}${IPC_PATH}`,
    token,
    coreVersion: "0.1.0",
    log,
    reconnect: false,
  });
  return client;
}

beforeEach(async () => {
  // ephemeral port (0) avoids collisions across test files
  shell = await startFakeShell({ port: 0, emitEvents: true });
});
afterEach(async () => {
  await shell.close();
});

describe("IpcClient against the fake shell", () => {
  it("handshakes, pings with RTT, queries permissions, draws overlay", async () => {
    const client = connect(shell.token);
    await client.connect();

    const pong = await client.call("shell.ping", { nonce: "n1" });
    expect(pong.nonce).toBe("n1");
    expect(typeof pong.shellTimeMs).toBe("number");

    const perms = await client.call("permissions.query", {});
    expect(perms.accessibility).toBe("not_determined");

    const drawn = await client.call("overlay.draw", {
      items: [{ kind: "spotlight", rect: { x: 1, y: 2, width: 3, height: 4 }, caption: "hi" }],
    });
    expect(drawn.drawn).toBe(1);
    client.close();
  });

  it("surfaces REFUSED as a typed error", async () => {
    const client = connect(shell.token);
    await client.connect();
    await expect(client.call("input.key", { pid: 123, keys: "cmd+b" })).rejects.toMatchObject({
      code: -32000,
    });
    try {
      await client.call("input.key", { pid: 123, keys: "cmd+s" });
    } catch (e) {
      expect(e).toBeInstanceOf(RpcCallError);
      expect((e as RpcCallError).data).toMatchObject({ reason: "possession_not_held" });
    }
    client.close();
  });

  it("receives pushed events (workspace.frontmostChanged)", async () => {
    const client = connect(shell.token);
    const got = new Promise<string | null>((resolve) => {
      client.on("workspace.frontmostChanged", (e) => resolve(e.bundleId));
    });
    await client.connect();
    expect(await got).toBe("com.apple.TextEdit");
    client.close();
  });

  it("rejects the handshake on a bad token", async () => {
    const client = connect("wrong-token");
    await expect(client.connect()).rejects.toBeInstanceOf(RpcCallError);
    client.close();
  });
});
