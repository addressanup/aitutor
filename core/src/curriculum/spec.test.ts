import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { LessonSpec, parseLessonSpec } from "./spec.ts";

const sample = readFileSync(join(import.meta.dirname, "fixtures", "sample-lesson.yaml"), "utf8");

describe("LessonSpec", () => {
  it("parses the app-neutral sample lesson", () => {
    const spec = parseLessonSpec(sample);
    expect(spec.lesson).toBe("textedit.u1.l1");
    expect(spec.app.bundleId).toBe("com.apple.TextEdit");
    expect(spec.skills.teaches).toContain("text.bold");
    expect(spec.demo.map((d) => d.id)).toEqual(["d1", "d2"]);
    expect(spec.rubric.reduce((s, r) => s + r.weight, 0)).toBeCloseTo(1);
  });

  it("defaults optional arrays", () => {
    const spec = LessonSpec.parse({
      lesson: "x.l1",
      version: "0.1.0",
      app: { bundleId: "com.example.app" },
      skills: { teaches: ["a"] },
      practice: { task: "do the thing" },
    });
    expect(spec.explain).toEqual([]);
    expect(spec.skills.requires).toEqual([]);
  });

  it("rejects a non-semver lesson version", () => {
    expect(() =>
      LessonSpec.parse({
        lesson: "x.l1",
        version: "1",
        app: { bundleId: "com.example.app" },
        skills: { teaches: ["a"] },
        practice: { task: "t" },
      }),
    ).toThrow();
  });
});
