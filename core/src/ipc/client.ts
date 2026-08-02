import {
  ErrorCodes,
  EVENTS,
  type EventMethod,
  HELLO_TIMEOUT_MS,
  MIN_SUPPORTED,
  PROTOCOL_VERSION,
  parseFrame,
  REQUEST_TIMEOUT_MS,
  REQUESTS,
  type RequestMethod,
} from "@aitutor/protocol";
import type { z } from "zod";
import type { Logger } from "../log.ts";
import { Backoff } from "./backoff.ts";

/**
 * Agent-core IPC client over the platform-native WebSocket (undici, Node 26 —
 * zero transport deps). Request/response correlation by id, per-request timeout,
 * zod-validated inbound frames, reconnect with jittered backoff and re-hello.
 *
 * The client speaks only the typed protocol v0 surface; unknown inbound frames
 * are logged and dropped, never thrown.
 */

type Params<M extends RequestMethod> = z.input<(typeof REQUESTS)[M]["params"]>;
type Result<M extends RequestMethod> = z.infer<(typeof REQUESTS)[M]["result"]>;
type EventPayload<E extends EventMethod> = z.infer<(typeof EVENTS)[E]>;
type EventHandler<E extends EventMethod> = (payload: EventPayload<E>) => void;

export class RpcCallError extends Error {
  readonly code: number;
  readonly data?: unknown;
  constructor(code: number, message: string, data?: unknown) {
    super(message);
    this.name = "RpcCallError";
    this.code = code;
    this.data = data;
  }
}

interface Pending {
  resolve: (value: unknown) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout>;
  method: string;
}

export interface IpcClientOptions {
  url: string;
  token: string;
  coreVersion: string;
  log: Logger;
  /** false in tests to keep a failed connect from looping. */
  reconnect?: boolean;
}

export class IpcClient {
  private ws: WebSocket | null = null;
  private readonly pending = new Map<string, Pending>();
  private readonly handlers = new Map<EventMethod, Set<(p: unknown) => void>>();
  private nextId = 1;
  private closed = false;
  private readonly backoff = new Backoff();
  private sessionId: string | null = null;
  private helloResolve: (() => void) | null = null;
  private helloReject: ((e: Error) => void) | null = null;
  private readonly opts: IpcClientOptions;

  constructor(opts: IpcClientOptions) {
    this.opts = opts;
  }

  on<E extends EventMethod>(event: E, handler: EventHandler<E>): void {
    let set = this.handlers.get(event);
    if (!set) {
      set = new Set();
      this.handlers.set(event, set);
    }
    set.add(handler as (p: unknown) => void);
  }

  /** Connect and complete the version handshake; resolves once hello succeeds. */
  connect(): Promise<void> {
    this.closed = false;
    return this.openOnce();
  }

  private openOnce(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.helloResolve = resolve;
      this.helloReject = reject;
      const ws = new WebSocket(this.opts.url);
      this.ws = ws;

      ws.addEventListener("open", () => {
        void this.sendHello();
      });
      ws.addEventListener("message", (ev: MessageEvent) => {
        this.onMessage(typeof ev.data === "string" ? ev.data : String(ev.data));
      });
      ws.addEventListener("error", () => {
        // 'close' handles recovery; error alone is noisy.
      });
      ws.addEventListener("close", (ev: CloseEvent) => {
        this.onClose(ev.code, ev.reason);
      });
    });
  }

  private async sendHello(): Promise<void> {
    try {
      const result = await this.call("session.hello", {
        protocolMin: MIN_SUPPORTED,
        protocolMax: PROTOCOL_VERSION,
        coreVersion: this.opts.coreVersion,
        token: this.opts.token,
        ...(this.sessionId ? { resumeSessionId: this.sessionId } : {}),
      });
      this.sessionId = result.sessionId;
      this.backoff.reset();
      this.opts.log.info(
        {
          protocol: result.protocolVersion,
          shell: result.shellVersion,
          sessionId: result.sessionId,
        },
        "ipc handshake complete",
      );
      this.helloResolve?.();
      this.helloResolve = null;
      this.helloReject = null;
    } catch (err) {
      this.opts.log.error({ err }, "handshake failed");
      this.helloReject?.(err as Error);
      this.helloResolve = null;
      this.helloReject = null;
      this.ws?.close();
    }
  }

  /** Typed request. Rejects with RpcCallError on a protocol error (incl. REFUSED). */
  call<M extends RequestMethod>(method: M, params: Params<M>): Promise<Result<M>> {
    const ws = this.ws;
    if (!ws || ws.readyState !== WebSocket.OPEN) {
      return Promise.reject(new RpcCallError(ErrorCodes.INTERNAL_ERROR, "socket not open"));
    }
    const id = `c-${this.nextId++}`;
    const timeoutMs = method === "overlay.draw" ? 2_000 : REQUEST_TIMEOUT_MS;
    const frame = { jsonrpc: "2.0" as const, id, method, params };

    return new Promise<Result<M>>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new RpcCallError(ErrorCodes.TIMEOUT, `request ${method} timed out`));
      }, timeoutMs);
      this.pending.set(id, {
        method,
        timer,
        reject,
        resolve: (value) => {
          const parsed = REQUESTS[method].result.parse(value);
          resolve(parsed as Result<M>);
        },
      });
      ws.send(JSON.stringify(frame));
    });
  }

  private onMessage(text: string): void {
    let frame: ReturnType<typeof parseFrame>;
    try {
      frame = parseFrame(text);
    } catch (err) {
      this.opts.log.warn({ err, text: text.slice(0, 200) }, "dropping unparseable frame");
      return;
    }

    if (frame.kind === "result" || frame.kind === "error") {
      const pending = this.pending.get(frame.frame.id);
      if (!pending) return;
      this.pending.delete(frame.frame.id);
      clearTimeout(pending.timer);
      if (frame.kind === "result") {
        try {
          pending.resolve(frame.frame.result);
        } catch (err) {
          pending.reject(err as Error);
        }
      } else {
        const e = frame.frame.error;
        pending.reject(new RpcCallError(e.code, e.message, e.data));
      }
      return;
    }

    if (frame.kind === "notification") {
      this.dispatchEvent(frame.frame.method, frame.frame.params);
      return;
    }
    // Requests from the shell are not part of v0; ignore.
    this.opts.log.warn({ method: frame.frame.method }, "unexpected inbound request; ignoring");
  }

  private dispatchEvent(method: string, params: unknown): void {
    if (!(method in EVENTS)) {
      this.opts.log.warn({ method }, "unknown event; ignoring");
      return;
    }
    const event = method as EventMethod;
    const parsed = EVENTS[event].safeParse(params);
    if (!parsed.success) {
      this.opts.log.warn({ method, issues: parsed.error.issues }, "malformed event; ignoring");
      return;
    }
    for (const h of this.handlers.get(event) ?? []) h(parsed.data);
  }

  private onClose(code: number, reason: string): void {
    for (const [, p] of this.pending) {
      clearTimeout(p.timer);
      p.reject(new RpcCallError(ErrorCodes.INTERNAL_ERROR, `socket closed (${code})`));
    }
    this.pending.clear();
    this.ws = null;
    if (this.helloReject) {
      this.helloReject(
        new RpcCallError(ErrorCodes.INTERNAL_ERROR, `closed during handshake (${code})`),
      );
      this.helloResolve = null;
      this.helloReject = null;
    }
    if (this.closed || this.opts.reconnect === false) return;
    const delay = this.backoff.next();
    this.opts.log.warn({ code, reason, delay }, "ipc closed; reconnecting");
    setTimeout(() => {
      if (!this.closed) void this.openOnce().catch(() => {});
    }, delay);
  }

  close(): void {
    this.closed = true;
    this.ws?.close();
    this.ws = null;
  }
}

export { HELLO_TIMEOUT_MS };
