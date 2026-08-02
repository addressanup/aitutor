import { z } from "zod";

/**
 * Coordinate convention (normative): screen POINTS, origin TOP-LEFT of the main
 * display — AX/screenshot space. Converting from Cocoa's bottom-left origin is
 * the shell's concern; frames on the wire are always top-left.
 */
export const Rect = z.object({
  x: z.number(),
  y: z.number(),
  width: z.number().nonnegative(),
  height: z.number().nonnegative(),
});
export type Rect = z.infer<typeof Rect>;

export const PermissionName = z.enum([
  "microphone",
  "screenRecording",
  "accessibility",
  "inputMonitoring",
]);
export type PermissionName = z.infer<typeof PermissionName>;

export const PermissionState = z.enum(["granted", "denied", "not_determined"]);
export type PermissionState = z.infer<typeof PermissionState>;

export const PossessionHolder = z.enum(["tutor", "learner", "idle"]);
export type PossessionHolder = z.infer<typeof PossessionHolder>;

export const PossessionCause = z.enum([
  "grant",
  "hardware_interrupt",
  "release",
  "panic",
  "timeout",
]);
export type PossessionCause = z.infer<typeof PossessionCause>;

export const InterruptKind = z.enum(["keyboard", "mouse", "double_esc"]);
export type InterruptKind = z.infer<typeof InterruptKind>;
