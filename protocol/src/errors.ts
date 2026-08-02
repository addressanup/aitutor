import { z } from "zod";

/** Standard JSON-RPC 2.0 codes plus aitutor extensions (-32000..-32004). */
export const ErrorCodes = {
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
  /** The shell declines the action — the "every tool is a call the shell can refuse" invariant. */
  REFUSED: -32000,
  INCOMPATIBLE_PROTOCOL: -32001,
  INVALID_TOKEN: -32002,
  TIMEOUT: -32003,
  SHELL_BUSY: -32004,
} as const;
export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

export const RefuseReason = z.enum([
  "permission_denied",
  "possession_not_held",
  "app_not_whitelisted",
  "forbidden_verb",
  "learner_interrupt",
]);
export type RefuseReason = z.infer<typeof RefuseReason>;

export const ErrorData = z
  .object({
    reason: RefuseReason.optional(),
    retryable: z.boolean().optional(),
    details: z.unknown().optional(),
  })
  .loose();
export type ErrorData = z.infer<typeof ErrorData>;

export const RpcError = z.object({
  code: z.number().int(),
  message: z.string(),
  data: ErrorData.optional(),
});
export type RpcError = z.infer<typeof RpcError>;
