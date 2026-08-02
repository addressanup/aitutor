import { z } from "zod";
import { PermissionState, Rect } from "./types.ts";

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

export const REQUESTS = {
  "session.hello": { params: HelloParams, result: HelloResult },
  "shell.ping": { params: PingParams, result: PingResult },
  "permissions.query": { params: PermissionsQueryParams, result: PermissionsQueryResult },
  "overlay.draw": { params: OverlayDrawParams, result: OverlayDrawResult },
  "overlay.clear": { params: OverlayClearParams, result: OverlayClearResult },
  "input.key": { params: InputKeyParams, result: InputKeyResult },
} as const;
export type RequestMethod = keyof typeof REQUESTS;

/** Named so nobody re-invents naming later; NOT defined in v0. */
export const RESERVED_METHODS = [
  "screen.observe",
  "ax.query",
  "ax.act",
  "input.click",
  "voice.say",
  "board.draw",
  "lesson.checkpoint",
] as const;
