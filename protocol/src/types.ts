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

/**
 * Coordinate convention (normative): screen POINTS, origin TOP-LEFT of the main
 * display — AX/screenshot space. Converting from Cocoa's bottom-left origin is
 * the shell's concern; points on the wire are always top-left.
 */
export const Point = z.object({
  x: z.number(),
  y: z.number(),
});
export type Point = z.infer<typeof Point>;

/**
 * One accessibility element, flattened. `ax.query` answers with a PRE-ORDER LIST
 * carrying `depth` rather than a nested tree: that is literally what the shell's
 * AXElement.descendants(maxDepth:maxNodes:) yields, and a flat list keeps both
 * mirrors free of recursive-schema machinery.
 *
 * Fields track AXElement's readable attributes one-for-one (role, subrole, title,
 * identifier, stringValue → `value`, actions(), frame). `role` is required: the
 * shell omits any element whose AXRole is unreadable rather than inventing one.
 * `frame` is absent when position or size is unreadable — common for menu items.
 */
export const AXNode = z.object({
  depth: z.number().int().nonnegative(),
  role: z.string(),
  subrole: z.string().optional(),
  title: z.string().optional(),
  identifier: z.string().optional(),
  value: z.string().optional(),
  actions: z.array(z.string()),
  frame: Rect.optional(),
});
export type AXNode = z.infer<typeof AXNode>;

/**
 * How the shell finds ONE element to act on. At least one of `identifier`, `title`,
 * `menuPath` must be present, and the shell requires the match to advertise the AX
 * action being asked for — the axdrive `press` rule, which is why popups and
 * disclosure triangles resolve as well as AXButtons. `menuPath` is a title path
 * through the app's menu bar (AXElement.menuBarItem(path:)), e.g. ["File", "Export…"].
 */
export const AXTarget = z.object({
  identifier: z.string().optional(),
  title: z.string().optional(),
  role: z.string().optional(),
  menuPath: z.array(z.string().min(1)).min(1).optional(),
});
export type AXTarget = z.infer<typeof AXTarget>;

/** Subtree `ax.query` walks: the whole app, its focused window, or its menu bar. */
export const AXQueryScope = z.enum(["application", "focused_window", "menu_bar"]);
export type AXQueryScope = z.infer<typeof AXQueryScope>;

/**
 * What `ax.act` does through the ACCESSIBILITY channel — never synthetic HID.
 * `press` is AXPress; `perform` names any other advertised AXAction (AXConfirm on a
 * save panel's name field, say); `set_value` is AXUIElementSetAttributeValue on
 * AXValue; `menu` presses a menu-bar item along `target.menuPath`; `activate`
 * brings the app frontmost. Pointer verbs live on `input.click`, not here.
 */
export const AXActVerb = z.enum(["press", "perform", "set_value", "menu", "activate"]);
export type AXActVerb = z.infer<typeof AXActVerb>;

export const MouseButton = z.enum(["left", "right"]);
export type MouseButton = z.infer<typeof MouseButton>;

/** Chord modifiers, spelled as the shell's action driver accepts them. */
export const KeyModifier = z.enum(["cmd", "shift", "opt", "ctrl"]);
export type KeyModifier = z.infer<typeof KeyModifier>;

/** What `screen.observe` looks at. `rect` requires the params' explicit `rect`. */
export const ObserveRegion = z.enum(["full_screen", "active_window", "rect"]);
export type ObserveRegion = z.infer<typeof ObserveRegion>;

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
