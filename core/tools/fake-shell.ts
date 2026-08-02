import {
  DEFAULT_IPC_PORT,
  ErrorCodes,
  IPC_PATH,
  PROTOCOL_VERSION,
  parseFrame,
} from "@aitutor/protocol";
import type { WebSocket } from "ws";
import { WebSocketServer } from "ws";

/**
 * A TypeScript stand-in for the Swift shell — implements all of protocol v0 so the
 * agent-core can be developed and tested without the native app. It DELIBERATELY
 * mirrors the real shell's refusal posture: input.key is always REFUSED. Used by
 * `make fakeshell`, the in-process demo, and the client integration test.
 */

export interface FakeShellHandle {
  port: number;
  token: string;
  close(): Promise<void>;
}

interface FakeShellOptions {
  port?: number;
  token?: string;
  /** Push a possession.changed + hardware.interrupt shortly after hello, to exercise events. */
  emitEvents?: boolean;
}

export function startFakeShell(opts: FakeShellOptions = {}): Promise<FakeShellHandle> {
  const token = opts.token ?? "dev-token";
  const wss = new WebSocketServer({
    host: "127.0.0.1",
    port: opts.port ?? DEFAULT_IPC_PORT,
    path: IPC_PATH,
  });

  wss.on("connection", (ws: WebSocket) => {
    let authed = false;
    const helloTimer = setTimeout(() => {
      if (!authed) ws.close(4401, "no hello");
    }, 3000);

    ws.on("message", (raw: Buffer) => {
      let frame: ReturnType<typeof parseFrame>;
      try {
        frame = parseFrame(raw.toString("utf8"));
      } catch {
        return;
      }
      if (frame.kind !== "request") return;
      const { id, method, params } = frame.frame;
      const ok = (result: Record<string, unknown>) =>
        ws.send(JSON.stringify({ jsonrpc: "2.0", id, result }));
      const err = (code: number, message: string, data?: unknown) =>
        ws.send(
          JSON.stringify({
            jsonrpc: "2.0",
            id,
            error: { code, message, ...(data ? { data } : {}) },
          }),
        );

      switch (method) {
        case "session.hello": {
          if (params.token !== token) {
            err(ErrorCodes.INVALID_TOKEN, "bad token");
            ws.close(4401, "bad token");
            return;
          }
          authed = true;
          clearTimeout(helloTimer);
          ok({
            protocolVersion: PROTOCOL_VERSION,
            shellVersion: "0.1.0-fake",
            sessionId: `sess-${Date.now().toString(36)}`,
            capabilities: ["permissions", "overlay"],
          });
          if (opts.emitEvents) {
            setTimeout(() => {
              ws.send(
                JSON.stringify({
                  jsonrpc: "2.0",
                  method: "workspace.frontmostChanged",
                  params: { bundleId: "com.apple.TextEdit", appName: "TextEdit", atMs: Date.now() },
                }),
              );
            }, 20);
          }
          return;
        }
        case "shell.ping":
          return void ok({ nonce: params.nonce, shellTimeMs: Date.now() });
        case "permissions.query":
          return void ok({
            microphone: "not_determined",
            screenRecording: "not_determined",
            accessibility: "not_determined",
            inputMonitoring: "not_determined",
          });
        case "overlay.draw": {
          const items = Array.isArray(params.items) ? params.items : [];
          return void ok({ drawn: items.length });
        }
        case "overlay.clear":
          return void ok({});
        case "input.key":
          // The refusal invariant, mirrored: the shell never posts synthetic input at scaffold.
          return void err(ErrorCodes.REFUSED, "refused: possession_not_held", {
            reason: "possession_not_held",
            retryable: false,
          });
        default:
          return void err(ErrorCodes.METHOD_NOT_FOUND, `unknown method: ${method}`);
      }
    });
  });

  return new Promise((resolve) => {
    wss.on("listening", () => {
      const addr = wss.address();
      const port = typeof addr === "object" && addr ? addr.port : (opts.port ?? DEFAULT_IPC_PORT);
      resolve({
        port,
        token,
        close: () =>
          new Promise<void>((res) => {
            for (const c of wss.clients) c.terminate();
            wss.close(() => res());
          }),
      });
    });
  });
}

// CLI entry: `node tools/fake-shell.ts`
if (import.meta.filename === process.argv[1]) {
  startFakeShell({ port: DEFAULT_IPC_PORT, emitEvents: true }).then((h) => {
    console.log(`[fake-shell] listening ws://127.0.0.1:${h.port}${IPC_PATH} token=${h.token}`);
  });
}
