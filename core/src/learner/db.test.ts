import { describe, expect, it } from "vitest";
import { openDatabase } from "./db.ts";

describe("learner db", () => {
  it("opens in-memory, migrates to user_version 1, and round-trips mastery", () => {
    const db = openDatabase(":memory:");
    const v = db.prepare("PRAGMA user_version").get() as { user_version: number };
    expect(v.user_version).toBe(1);

    db.prepare(
      "INSERT INTO skill_mastery (skill_id, log_odds, evidence_count, updated_ms) VALUES (?, ?, ?, ?)",
    ).run("timeline.blade", 0.4, 3, 1_000);
    const row = db
      .prepare("SELECT log_odds, evidence_count FROM skill_mastery WHERE skill_id = ?")
      .get("timeline.blade") as { log_odds: number; evidence_count: number };
    expect(row.log_odds).toBeCloseTo(0.4);
    expect(row.evidence_count).toBe(3);
  });

  it("re-opening is idempotent (migration guard)", () => {
    const db = openDatabase(":memory:");
    expect(() => openDatabase(":memory:")).not.toThrow();
    expect((db.prepare("PRAGMA user_version").get() as { user_version: number }).user_version).toBe(
      1,
    );
  });
});
