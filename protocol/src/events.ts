import { z } from "zod";
import {
  InterruptKind,
  PermissionName,
  PermissionState,
  PossessionCause,
  PossessionHolder,
} from "./types.ts";

/** shell→core notifications (no id, no response). */

export const PermissionStatusEvent = z.object({
  permission: PermissionName,
  status: PermissionState,
});

export const PossessionChangedEvent = z.object({
  holder: PossessionHolder,
  cause: PossessionCause,
  atMs: z.number(),
});

/** Low-latency signal; a possession.changed follows if a lease was revoked. */
export const HardwareInterruptEvent = z.object({
  kind: InterruptKind,
  atMs: z.number(),
});

/** NSWorkspace frontmost-app change — zero TCC required; proves the push direction. */
export const FrontmostChangedEvent = z.object({
  bundleId: z.string().nullable(),
  appName: z.string().optional(),
  atMs: z.number(),
});

export const EVENTS = {
  "permission.status": PermissionStatusEvent,
  "possession.changed": PossessionChangedEvent,
  "hardware.interrupt": HardwareInterruptEvent,
  "workspace.frontmostChanged": FrontmostChangedEvent,
} as const;
export type EventMethod = keyof typeof EVENTS;
