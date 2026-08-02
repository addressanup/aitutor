import { describe, expect, it } from "vitest";
import { compareSemver, negotiate, parseSemver } from "./negotiate.ts";

describe("semver", () => {
  it("parses and compares", () => {
    expect(parseSemver("0.1.0")).toEqual([0, 1, 0]);
    expect(parseSemver("1.2")).toBeNull();
    expect(compareSemver("0.1.0", "0.1.0")).toBe(0);
    expect(compareSemver("0.2.0", "0.10.0")).toBe(-1);
    expect(compareSemver("1.0.0", "0.9.9")).toBe(1);
  });
});

describe("negotiate", () => {
  it("picks the exact match", () => {
    expect(negotiate("0.1.0", "0.1.0", ["0.1.0"])).toBe("0.1.0");
  });
  it("picks the highest supported inside the range", () => {
    expect(negotiate("0.1.0", "0.3.0", ["0.1.0", "0.2.0"])).toBe("0.2.0");
  });
  it("fails when nothing overlaps (incompatible major is out of range by ordering)", () => {
    expect(negotiate("1.0.0", "1.2.0", ["0.9.0"])).toBeNull();
    expect(negotiate("0.1.0", "0.1.0", ["1.0.0"])).toBeNull();
    expect(negotiate("0.1.0", "0.1.0", [])).toBeNull();
  });
  it("fails on malformed input rather than guessing", () => {
    expect(negotiate("junk", "0.1.0", ["0.1.0"])).toBeNull();
    expect(negotiate("0.1.0", "0.1.0", ["junk"])).toBeNull();
  });
});
