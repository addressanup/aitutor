/**
 * Model tiering + prompt-cache discipline (docs/execution-plan.md §2).
 * Constants only — no SDK, no key, no call at scaffold.
 */

export const ModelTier = {
  /** Demo supervision, assessment moments, planning, recovery. */
  judgment: "claude-opus-5",
  /** Narration + feedback turns. */
  narration: "claude-sonnet-5",
  /** Continuous pre-screening (migrates on-device later). */
  prescreen: "claude-haiku-4-5",
} as const;
export type ModelTier = (typeof ModelTier)[keyof typeof ModelTier];

/** Frozen lesson-pack prefix is cached at this TTL; volatile state is injected AFTER it. */
export const CACHE_TTL = "1h" as const;

/**
 * How volatile session state is injected without invalidating the cached prefix.
 * Mid-conversation role:"system" is supported on Opus 5 but NOT Sonnet 5 / Haiku,
 * which use a <system-reminder> block inside a user turn instead. Encoding this
 * from day one keeps a later cache-buster (≈6× COGS) out of the codebase.
 */
export const VOLATILE_INJECTION: Record<ModelTier, "system_message" | "system_reminder"> = {
  [ModelTier.judgment]: "system_message",
  [ModelTier.narration]: "system_reminder",
  [ModelTier.prescreen]: "system_reminder",
};
