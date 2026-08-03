import { z } from "zod";
import {
  AXActVerb,
  AXNode,
  AXQueryScope,
  AXTarget,
  KeyModifier,
  MouseButton,
  ObserveRegion,
  PermissionState,
  Point,
  Rect,
} from "./types.ts";

/** core→shell requests. The shell may answer any of these with error REFUSED (-32000). */

export const HelloParams = z.object({
  protocolMin: z.string(),
  protocolMax: z.string(),
  coreVersion: z.string(),
  token: z.string(),
  resumeSessionId: z.string().optional(),
});
export const HelloResult = z.object({
  protocolVersion: z.string(),
  shellVersion: z.string(),
  sessionId: z.string(),
  capabilities: z.array(z.string()),
});

export const PingParams = z.object({ nonce: z.string() });
export const PingResult = z.object({ nonce: z.string(), shellTimeMs: z.number() });

export const PermissionsQueryParams = z.object({});
export const PermissionsQueryResult = z.object({
  microphone: PermissionState,
  screenRecording: PermissionState,
  accessibility: PermissionState,
  inputMonitoring: PermissionState,
});

export const OverlayItem = z.object({
  kind: z.literal("spotlight"),
  rect: Rect,
  caption: z.string().optional(),
});
export const OverlayDrawParams = z.object({
  items: z.array(OverlayItem).min(1),
  ttlMs: z.number().int().positive().optional(),
});
export const OverlayDrawResult = z.object({ drawn: z.number().int().nonnegative() });

export const OverlayClearParams = z.object({});
export const OverlayClearResult = z.object({});

/**
 * Defined in v0 so the refusal invariant is visible from day one: at scaffold the
 * shell ALWAYS answers REFUSED (reason: possession_not_held). A dev flag may log a
 * dry-run "would post to pid N" — it never posts.
 */
export const InputKeyParams = z.object({
  pid: z.number().int().positive(),
  keys: z.string().min(1),
});
export const InputKeyResult = z.object({ posted: z.boolean(), dryRun: z.boolean() });

/**
 * v0.2 (additive) — the act/observe surface. Schemas and fixtures only: the shell has
 * no handlers for these yet, so a v0.2 shell answers METHOD_NOT_FOUND until Sprint 1
 * wires AXBridge behind them. A shell advertises `ax` / `input` / `screen` in
 * `session.hello`'s `capabilities` only once the matching handler exists.
 *
 * Two addressing modes, deliberately different. The AX methods take `bundleId`,
 * because the AX channel is app-scoped and a bundle id is what a session whitelist
 * and an audit record can be written against; the shell resolves the pid itself and
 * echoes it back. The synthetic-HID methods take `pid`, because CGEventPostToPid
 * takes a pid — and because `input.key` already froze that shape in v0.
 */

/**
 * Read an app's accessibility tree. `maxDepth`/`maxNodes` are required bounds, not
 * hints: browser-backed AX trees are large enough that an unbounded walk is a hang.
 * `menuPath` narrows a `menu_bar` scope to one submenu.
 */
export const AXQueryParams = z.object({
  bundleId: z.string().min(1),
  scope: AXQueryScope,
  maxDepth: z.number().int().positive(),
  maxNodes: z.number().int().positive().optional(),
  menuPath: z.array(z.string().min(1)).min(1).optional(),
});
export type AXQueryParams = z.infer<typeof AXQueryParams>;

/** `truncated` is true when the walk stopped on `maxNodes`/`maxDepth` — the tree is larger. */
export const AXQueryResult = z.object({
  pid: z.number().int().positive(),
  nodes: z.array(AXNode),
  truncated: z.boolean(),
});
export type AXQueryResult = z.infer<typeof AXQueryResult>;

/**
 * Act through the accessibility channel. Per verb: `press` and `perform` need
 * `target` (and `perform` needs `action`); `set_value` needs `target` + `value`;
 * `menu` needs `target.menuPath`; `activate` needs neither.
 */
export const AXActParams = z.object({
  bundleId: z.string().min(1),
  verb: AXActVerb,
  target: AXTarget.optional(),
  action: z.string().min(1).optional(),
  value: z.string().optional(),
});
export type AXActParams = z.infer<typeof AXActParams>;

/**
 * `performed` false means the element resolved but the AX API declined — a refusal by
 * the SHELL is an error frame (REFUSED), never a false here. `matched` is the element
 * the shell actually acted on, so the core can journal what it hit rather than what it
 * asked for.
 */
export const AXActResult = z.object({
  performed: z.boolean(),
  matched: AXNode.optional(),
});
export type AXActResult = z.infer<typeof AXActResult>;

/**
 * Synthetic pointer input — same posture and same refusal invariant as `input.key`:
 * REFUSED (`possession_not_held`) without a lease, dev flag logs a dry run and never
 * posts. `clickCount` 2 is the double-click; drag is deliberately NOT folded in here
 * (a press-move-release path is a different shape and waits for its own method).
 */
export const InputClickParams = z.object({
  pid: z.number().int().positive(),
  point: Point,
  button: MouseButton.optional(),
  clickCount: z.number().int().min(1).max(2).optional(),
  modifiers: z.array(KeyModifier).optional(),
});
export type InputClickParams = z.infer<typeof InputClickParams>;

export const InputClickResult = z.object({ posted: z.boolean(), dryRun: z.boolean() });
export type InputClickResult = z.infer<typeof InputClickResult>;

/** `rect` is required when `region` is `rect`, ignored otherwise. */
export const ScreenObserveParams = z.object({
  region: ObserveRegion,
  rect: Rect.optional(),
});
export type ScreenObserveParams = z.infer<typeof ScreenObserveParams>;

/**
 * Metadata only, on purpose. CapturePipeline.captureOnce() is still a stub, so the
 * honest answer today is `imageAvailable: false` with the region the shell WOULD have
 * captured. No image bytes cross this wire in v0.2; how a frame reaches the model
 * (handle, file path, or side channel) is a later additive minor.
 */
export const ScreenObserveResult = z.object({
  atMs: z.number(),
  frame: Rect,
  imageAvailable: z.boolean(),
});
export type ScreenObserveResult = z.infer<typeof ScreenObserveResult>;

export const REQUESTS = {
  "session.hello": { params: HelloParams, result: HelloResult },
  "shell.ping": { params: PingParams, result: PingResult },
  "permissions.query": { params: PermissionsQueryParams, result: PermissionsQueryResult },
  "overlay.draw": { params: OverlayDrawParams, result: OverlayDrawResult },
  "overlay.clear": { params: OverlayClearParams, result: OverlayClearResult },
  "input.key": { params: InputKeyParams, result: InputKeyResult },
  "ax.query": { params: AXQueryParams, result: AXQueryResult },
  "ax.act": { params: AXActParams, result: AXActResult },
  "input.click": { params: InputClickParams, result: InputClickResult },
  "screen.observe": { params: ScreenObserveParams, result: ScreenObserveResult },
} as const;
export type RequestMethod = keyof typeof REQUESTS;

/** Named so nobody re-invents naming later; NOT defined through v0.2. */
export const RESERVED_METHODS = ["voice.say", "board.draw", "lesson.checkpoint"] as const;
