import { describe, expect, it } from "vitest";
import { FrameParseError, parseFrame } from "./envelope.ts";

describe("parseFrame", () => {
  it("round-trips a request", () => {
    const wire = JSON.stringify({
      jsonrpc: "2.0",
      id: "c-1",
      method: "shell.ping",
      params: { nonce: "abc" },
    });
    const parsed = parseFrame(wire);
    expect(parsed.kind).toBe("request");
    if (parsed.kind !== "request") throw new Error("unreachable");
    expect(parsed.frame.method).toBe("shell.ping");
    expect(parsed.frame.id).toBe("c-1");
  });

  it("classifies notifications (no id)", () => {
    const parsed = parseFrame(
      JSON.stringify({
        jsonrpc: "2.0",
        method: "hardware.interrupt",
        params: { kind: "mouse", atMs: 1 },
      }),
    );
    expect(parsed.kind).toBe("notification");
  });

  it("classifies result and error responses", () => {
    expect(parseFrame(JSON.stringify({ jsonrpc: "2.0", id: "c-2", result: {} })).kind).toBe(
      "result",
    );
    expect(
      parseFrame(
        JSON.stringify({ jsonrpc: "2.0", id: "c-3", error: { code: -32000, message: "refused" } }),
      ).kind,
    ).toBe("error");
  });

  it("tolerates unknown fields (forward compatibility within a major)", () => {
    const parsed = parseFrame(
      JSON.stringify({
        jsonrpc: "2.0",
        id: "c-9",
        method: "shell.ping",
        params: { nonce: "n", futureField: true },
        futureTopLevel: 42,
      }),
    );
    expect(parsed.kind).toBe("request");
  });

  it("rejects batch arrays", () => {
    expect(() => parseFrame("[]")).toThrow(FrameParseError);
    expect(() =>
      parseFrame(JSON.stringify([{ jsonrpc: "2.0", id: "1", method: "x", params: {} }])),
    ).toThrow(FrameParseError);
  });

  it("rejects non-JSON, non-objects, and shapeless frames", () => {
    expect(() => parseFrame("not json")).toThrow(FrameParseError);
    expect(() => parseFrame('"string"')).toThrow(FrameParseError);
    expect(() => parseFrame(JSON.stringify({ jsonrpc: "2.0", id: "c-1" }))).toThrow(
      FrameParseError,
    );
  });
});
