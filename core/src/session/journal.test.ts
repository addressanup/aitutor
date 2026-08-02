import { describe, expect, it } from "vitest";
import { openDatabase } from "../learner/db.ts";
import { Journal, readRows, replay, verifyChain } from "./journal.ts";
import { Phase, Possession } from "./machine.ts";

function seeded() {
  const db = openDatabase(":memory:");
  const j = new Journal(db, "sess-1");
  let t = 1_000;
  j.append({ type: "ADVANCE" }, t++); // → EXPLAIN
  j.append({ type: "ADVANCE" }, t++); // → DEMONSTRATE
  j.append({ type: "HARDWARE_INTERRUPT" }, t++); // → PAUSED / LEARNER
  j.append({ type: "RESUME" }, t++); // → DEMONSTRATE
  return db;
}

describe("journal", () => {
  it("appends monotonic seqs from a fresh session", () => {
    const db = seeded();
    const rows = readRows(db, "sess-1");
    expect(rows.map((r) => r.seq)).toEqual([0, 1, 2, 3]);
    expect(rows.map((r) => r.kind)).toEqual(["ADVANCE", "ADVANCE", "HARDWARE_INTERRUPT", "RESUME"]);
  });

  it("replay reproduces the machine state", () => {
    const state = replay(seeded(), "sess-1");
    expect(state.phase).toBe(Phase.DEMONSTRATE);
    expect(state.possession).toBe(Possession.IDLE);
  });

  it("hash chain verifies", () => {
    expect(verifyChain(seeded(), "sess-1")).toBe(true);
  });

  it("a tampered payload breaks the chain", () => {
    const db = seeded();
    db.prepare("UPDATE journal SET payload_json = ? WHERE seq = 1").run('{"type":"PANIC"}');
    expect(verifyChain(db, "sess-1")).toBe(false);
  });

  it("resumes seq + chain when reopened on the same session", () => {
    const db = seeded();
    const j2 = new Journal(db, "sess-1");
    j2.append({ type: "END_SESSION" }, 2_000);
    const rows = readRows(db, "sess-1");
    expect(rows.at(-1)?.seq).toBe(4);
    expect(verifyChain(db, "sess-1")).toBe(true);
    expect(replay(db, "sess-1").phase).toBe(Phase.ENDED);
  });
});
