import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { parseFrame } from "./envelope.ts";
import { ErrorCodes, RefuseReason } from "./errors.ts";
import { EVENTS } from "./events.ts";
import { REQUESTS } from "./methods.ts";

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
