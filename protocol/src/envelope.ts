import { z } from "zod";
import { RpcError } from "./errors.ts";

/**
 * JSON-RPC 2.0 subset over WebSocket TEXT frames: one JSON object per frame,
 * batch arrays rejected. Receivers MUST ignore unknown object fields
 * (forward compatibility within a major) — hence .loose() everywhere.
 * id convention: "c-<n>" core-originated, "s-<n>" shell-originated.
 */
export const RequestFrame = z
  .object({
    jsonrpc: z.literal("2.0"),
    id: z.string(),
    method: z.string(),
    params: z.record(z.string(), z.unknown()),
  })
  .loose();
export type RequestFrame = z.infer<typeof RequestFrame>;

export const NotificationFrame = z
  .object({
    jsonrpc: z.literal("2.0"),
    method: z.string(),
    params: z.record(z.string(), z.unknown()),
  })
  .loose();
export type NotificationFrame = z.infer<typeof NotificationFrame>;

export const ResultResponseFrame = z
  .object({
    jsonrpc: z.literal("2.0"),
    id: z.string(),
    result: z.record(z.string(), z.unknown()),
  })
  .loose();
export type ResultResponseFrame = z.infer<typeof ResultResponseFrame>;

export const ErrorResponseFrame = z
  .object({
    jsonrpc: z.literal("2.0"),
    id: z.string(),
    error: RpcError,
  })
  .loose();
export type ErrorResponseFrame = z.infer<typeof ErrorResponseFrame>;

export type Frame =
  | { kind: "request"; frame: RequestFrame }
  | { kind: "notification"; frame: NotificationFrame }
  | { kind: "result"; frame: ResultResponseFrame }
  | { kind: "error"; frame: ErrorResponseFrame };

export class FrameParseError extends Error {}

/** Parse one wire frame. Throws FrameParseError on batches, non-objects, or malformed frames. */
export function parseFrame(text: string): Frame {
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    throw new FrameParseError("frame is not valid JSON");
  }
  if (Array.isArray(raw)) throw new FrameParseError("batch frames are not supported");
  if (typeof raw !== "object" || raw === null) throw new FrameParseError("frame must be an object");

  const obj = raw as Record<string, unknown>;
  if ("method" in obj) {
    if ("id" in obj) return { kind: "request", frame: RequestFrame.parse(obj) };
    return { kind: "notification", frame: NotificationFrame.parse(obj) };
  }
  if ("result" in obj) return { kind: "result", frame: ResultResponseFrame.parse(obj) };
  if ("error" in obj) return { kind: "error", frame: ErrorResponseFrame.parse(obj) };
  throw new FrameParseError("frame is neither request, notification, nor response");
}
