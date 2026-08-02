/**
 * Demonstration engine types (docs/execution-plan.md §3.1). Semantic steps execute
 * down a capability ladder with per-step verification. INTERFACE ONLY at scaffold.
 */

/** T2 app adapter (deterministic) → T1 Accessibility → T0 computer-use vision. */
export const CapabilityTier = { T2: "T2", T1: "T1", T0: "T0" } as const;
export type CapabilityTier = (typeof CapabilityTier)[keyof typeof CapabilityTier];

export const StepPhase = {
  PLAN: "PLAN",
  TELEGRAPH: "TELEGRAPH",
  ACT: "ACT",
  VERIFY: "VERIFY",
  NARRATE: "NARRATE",
} as const;
export type StepPhase = (typeof StepPhase)[keyof typeof StepPhase];

export interface VerifyPredicate {
  ax?: string;
  timeoutS?: number;
}

export interface ExecutorBinding {
  tier: CapabilityTier;
  channel: "ax" | "keys" | "vision";
}

export interface SemanticStep {
  id: string;
  intent: string;
  bindings: ExecutorBinding[];
  narrate?: string;
  verify: VerifyPredicate;
}
