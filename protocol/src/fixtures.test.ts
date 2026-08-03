import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { parseFrame } from "./envelope.ts";
import { ErrorCodes, RefuseReason } from "./errors.ts";
import { EVENTS } from "./events.ts";
import { REQUESTS, RESERVED_METHODS } from "./methods.ts";
import { negotiate } from "./negotiate.ts";
import { MIN_SUPPORTED, PROTOCOL_VERSION, SUPPORTED_VERSIONS } from "./version.ts";

const FIXTURES = join(import.meta.dirname, "..", "fixtures");
const read = (name: string) => readFileSync(join(FIXTURES, name), "utf8");

describe("golden fixtures (mirrored by the Swift ShellProtocol tests)", () => {
  it("hello.request.json", () => {
    const parsed = parseFrame(read("hello.request.json"));
    expect(parsed.kind).toBe("request");
    if (parsed.kind !== "request") throw new Error("unreachable");
    REQUESTS["session.hello"].params.parse(parsed.frame.params);
  });

  it("hello.result.json", () => {
    const parsed = parseFrame(read("hello.result.json"));
    expect(parsed.kind).toBe("result");
    if (parsed.kind !== "result") throw new Error("unreachable");
    REQUESTS["session.hello"].result.parse(parsed.frame.result);
  });

  it("overlay-draw.request.json", () => {
    const parsed = parseFrame(read("overlay-draw.request.json"));
    if (parsed.kind !== "request") throw new Error("expected request");
    const params = REQUESTS["overlay.draw"].params.parse(parsed.frame.params);
    expect(params.items[0]?.kind).toBe("spotlight");
  });

  it("possession-changed.event.json", () => {
    const parsed = parseFrame(read("possession-changed.event.json"));
    if (parsed.kind !== "notification") throw new Error("expected notification");
    const params = EVENTS["possession.changed"].parse(parsed.frame.params);
    expect(params.cause).toBe("hardware_interrupt");
  });

  it("error-refused.json", () => {
    const parsed = parseFrame(read("error-refused.json"));
    if (parsed.kind !== "error") throw new Error("expected error");
    expect(parsed.frame.error.code).toBe(ErrorCodes.REFUSED);
    RefuseReason.parse(parsed.frame.error.data?.reason);
  });
});

describe("golden fixtures — protocol v0.2 (additive)", () => {
  it("hello-v02.request.json", () => {
    const parsed = parseFrame(read("hello-v02.request.json"));
    if (parsed.kind !== "request") throw new Error("expected request");
    const params = REQUESTS["session.hello"].params.parse(parsed.frame.params);
    expect(params.protocolMin).toBe(MIN_SUPPORTED);
    expect(params.protocolMax).toBe(PROTOCOL_VERSION);
  });

  it("hello-v02.result.json", () => {
    const parsed = parseFrame(read("hello-v02.result.json"));
    if (parsed.kind !== "result") throw new Error("expected result");
    const result = REQUESTS["session.hello"].result.parse(parsed.frame.result);
    expect(result.protocolVersion).toBe(PROTOCOL_VERSION);
    expect(result.capabilities).toContain("ax");
  });

  it("ax-query.request.json", () => {
    const parsed = parseFrame(read("ax-query.request.json"));
    if (parsed.kind !== "request") throw new Error("expected request");
    expect(parsed.frame.method).toBe("ax.query");
    const params = REQUESTS["ax.query"].params.parse(parsed.frame.params);
    expect(params.scope).toBe("focused_window");
    expect(params.maxDepth).toBe(4);
  });

  it("ax-query.result.json", () => {
    const parsed = parseFrame(read("ax-query.result.json"));
    if (parsed.kind !== "result") throw new Error("expected result");
    const result = REQUESTS["ax.query"].result.parse(parsed.frame.result);
    expect(result.nodes).toHaveLength(3);
    expect(result.nodes[0]?.depth).toBe(0);
    expect(result.nodes[1]?.actions).toEqual(["AXPress"]);
    expect(result.truncated).toBe(false);
  });

  it("ax-act.request.json", () => {
    const parsed = parseFrame(read("ax-act.request.json"));
    if (parsed.kind !== "request") throw new Error("expected request");
    expect(parsed.frame.method).toBe("ax.act");
    const params = REQUESTS["ax.act"].params.parse(parsed.frame.params);
    expect(params.verb).toBe("press");
    expect(params.target?.identifier).toBe("fixture-primary-button");
  });

  it("ax-act.result.json", () => {
    const parsed = parseFrame(read("ax-act.result.json"));
    if (parsed.kind !== "result") throw new Error("expected result");
    const result = REQUESTS["ax.act"].result.parse(parsed.frame.result);
    expect(result.performed).toBe(true);
    expect(result.matched?.role).toBe("AXButton");
  });

  it("input-click.request.json", () => {
    const parsed = parseFrame(read("input-click.request.json"));
    if (parsed.kind !== "request") throw new Error("expected request");
    expect(parsed.frame.method).toBe("input.click");
    const params = REQUESTS["input.click"].params.parse(parsed.frame.params);
    expect(params.point).toEqual({ x: 512, y: 384 });
    expect(params.clickCount).toBe(2);
    expect(params.modifiers).toEqual(["shift"]);
  });

  it("input-click.result.json", () => {
    const parsed = parseFrame(read("input-click.result.json"));
    if (parsed.kind !== "result") throw new Error("expected result");
    const result = REQUESTS["input.click"].result.parse(parsed.frame.result);
    // The refusal posture input.key froze in v0: nothing posts without a lease.
    expect(result.posted).toBe(false);
    expect(result.dryRun).toBe(true);
  });

  it("screen-observe.request.json", () => {
    const parsed = parseFrame(read("screen-observe.request.json"));
    if (parsed.kind !== "request") throw new Error("expected request");
    expect(parsed.frame.method).toBe("screen.observe");
    const params = REQUESTS["screen.observe"].params.parse(parsed.frame.params);
    expect(params.region).toBe("rect");
    expect(params.rect?.width).toBe(1440);
  });

  it("screen-observe.result.json", () => {
    const parsed = parseFrame(read("screen-observe.result.json"));
    if (parsed.kind !== "result") throw new Error("expected result");
    const result = REQUESTS["screen.observe"].result.parse(parsed.frame.result);
    // Honest while CapturePipeline.captureOnce() is a stub.
    expect(result.imageAvailable).toBe(false);
    expect(result.frame.height).toBe(900);
  });
});

describe("v0.2 is additive", () => {
  it("keeps every v0 method and reserves only the still-undefined names", () => {
    for (const method of ["session.hello", "shell.ping", "overlay.draw", "input.key"] as const) {
      expect(REQUESTS[method]).toBeDefined();
    }
    expect(RESERVED_METHODS).toEqual(["voice.say", "board.draw", "lesson.checkpoint"]);
    for (const method of RESERVED_METHODS) {
      expect(Object.keys(REQUESTS)).not.toContain(method);
    }
  });

  it("negotiates 0.1.0 with an N-1 peer and 0.2.0 with a current one", () => {
    expect(negotiate("0.1.0", "0.1.0", SUPPORTED_VERSIONS)).toBe("0.1.0");
    expect(negotiate(MIN_SUPPORTED, PROTOCOL_VERSION, SUPPORTED_VERSIONS)).toBe("0.2.0");
  });
});
