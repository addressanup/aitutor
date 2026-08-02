import type { CompleteRequest, CompleteResponse, ModelPort } from "./port.ts";
import { NotImplementedError } from "./port.ts";

/**
 * Stub. The real implementation (M0) lazily constructs the Anthropic SDK client,
 * routes by tier, and applies the cache/volatile-injection discipline from
 * tiers.ts. It throws until then so `pnpm test` needs no API key.
 */
export class AnthropicPort implements ModelPort {
  complete(_req: CompleteRequest): Promise<CompleteResponse> {
    throw new NotImplementedError("AnthropicPort.complete");
  }

  stream(_req: CompleteRequest): AsyncIterable<string> {
    throw new NotImplementedError("AnthropicPort.stream");
  }

  capabilities(): { vision: boolean; toolUse: boolean } {
    return { vision: true, toolUse: true };
  }
}
