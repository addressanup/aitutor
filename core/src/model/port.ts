import type { ModelTier } from "./tiers.ts";

/**
 * Vendor-agnostic model interface (docs/execution-plan.md §2). Anthropic is
 * primary but the moat lives in curriculum/adapters/learner-model/trust, never
 * raw capability — so this port stays swappable. INTERFACE ONLY at scaffold;
 * AnthropicPort is a throwing stub (no key required to run tests).
 */

export interface ModelMessage {
  role: "user" | "assistant";
  content: string;
}

export interface CompleteRequest {
  tier: ModelTier;
  system?: string;
  messages: ModelMessage[];
}

export interface CompleteResponse {
  text: string;
}

export interface ModelPort {
  complete(req: CompleteRequest): Promise<CompleteResponse>;
  stream(req: CompleteRequest): AsyncIterable<string>;
  capabilities(): { vision: boolean; toolUse: boolean };
}

export class NotImplementedError extends Error {
  constructor(what: string) {
    super(`${what} is not implemented at scaffold — scheduled for M0`);
    this.name = "NotImplementedError";
  }
}
