/**
 * Foveated observation (docs/execution-plan.md §3.3). Continuous semantic layer
 * (OS events) is ~$0; frontier deep looks fire only on named triggers under a
 * hard hourly budget. INTERFACE ONLY at scaffold.
 */

export const DeepLookTrigger = {
  LEARNER_QUESTION: "LEARNER_QUESTION",
  COMPLETION_CLAIM: "COMPLETION_CLAIM",
  RUBRIC_CHECKPOINT: "RUBRIC_CHECKPOINT",
  ERROR_SIGNATURE: "ERROR_SIGNATURE",
  IDLE_TIMEOUT: "IDLE_TIMEOUT",
  WATCHDOG: "WATCHDOG",
} as const;
export type DeepLookTrigger = (typeof DeepLookTrigger)[keyof typeof DeepLookTrigger];

/** Hard cap on frontier looks per hour — the existence condition of the economics. */
export const LOOK_BUDGET_PER_HOUR = 80;

export interface Observer {
  /** A deep look was requested for a given reason; returns whether budget allowed it. */
  requestDeepLook(trigger: DeepLookTrigger): Promise<{ allowed: boolean }>;
}
