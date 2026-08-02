import { describe, expect, it } from "vitest";
import {
  type Effect,
  initialState,
  Phase,
  Possession,
  type SessionEvent,
  transition,
} from "./machine.ts";

function run(events: SessionEvent[]) {
  let state = initialState();
  const effects: Effect[] = [];
  for (const e of events) {
    const r = transition(state, e);
    state = r.state;
    effects.push(...r.effects);
  }
  return { state, effects };
}

const ACTIVE = [
  Phase.EXPLAIN,
  Phase.DEMONSTRATE,
  Phase.ATTEMPT,
  Phase.FEEDBACK,
  Phase.ADAPT,
] as const;

describe("teaching-loop transitions", () => {
  it("walks INIT → EXPLAIN → … → ADAPT → EXPLAIN", () => {
    const seen: Phase[] = [];
    let state = initialState();
    for (let i = 0; i < 6; i++) {
      state = transition(state, { type: "ADVANCE" }).state;
      seen.push(state.phase);
    }
    expect(seen).toEqual([
      Phase.EXPLAIN,
      Phase.DEMONSTRATE,
      Phase.ATTEMPT,
      Phase.FEEDBACK,
      Phase.ADAPT,
      Phase.EXPLAIN,
    ]);
  });

  it("possession is orthogonal to phase", () => {
    const { state } = run([
      { type: "ADVANCE" },
      { type: "POSSESSION_CHANGED", holder: Possession.TUTOR },
    ]);
    expect(state.phase).toBe(Phase.EXPLAIN);
    expect(state.possession).toBe(Possession.TUTOR);
  });
});

describe("hardware interrupt", () => {
  for (const phase of ACTIVE) {
    it(`pauses from ${phase} and hands the learner control`, () => {
      // advance until we reach `phase`
      let state = initialState();
      while (state.phase !== phase) state = transition(state, { type: "ADVANCE" }).state;
      const r = transition(state, { type: "HARDWARE_INTERRUPT" });
      expect(r.state.phase).toBe(Phase.PAUSED);
      expect(r.state.possession).toBe(Possession.LEARNER);
      expect(r.state.resumePhase).toBe(phase);
      expect(r.effects.some((e) => e.kind === "releasePossession")).toBe(true);
    });
  }

  it("RESUME returns to the stored phase and clears it", () => {
    let state = initialState();
    state = transition(state, { type: "ADVANCE" }).state; // EXPLAIN
    state = transition(state, { type: "ADVANCE" }).state; // DEMONSTRATE
    state = transition(state, { type: "HARDWARE_INTERRUPT" }).state;
    expect(state.phase).toBe(Phase.PAUSED);
    const resumed = transition(state, { type: "RESUME" }).state;
    expect(resumed.phase).toBe(Phase.DEMONSTRATE);
    expect(resumed.possession).toBe(Possession.IDLE);
    expect(resumed.resumePhase).toBeNull();
  });

  it("is ignored outside active phases (INIT)", () => {
    const r = transition(initialState(), { type: "HARDWARE_INTERRUPT" });
    expect(r.state.phase).toBe(Phase.INIT);
    expect(r.effects[0]?.kind).toBe("ignored");
  });
});

describe("panic and recovery", () => {
  it("PANIC forces PAUSED + LEARNER with no resume", () => {
    let state = initialState();
    state = transition(state, { type: "ADVANCE" }).state; // EXPLAIN
    const r = transition(state, { type: "PANIC" });
    expect(r.state.phase).toBe(Phase.PAUSED);
    expect(r.state.possession).toBe(Possession.LEARNER);
    expect(r.state.resumePhase).toBeNull();
  });

  it("RECOVER → RECOVERED returns to where we were", () => {
    let state = initialState();
    state = transition(state, { type: "ADVANCE" }).state; // EXPLAIN
    state = transition(state, { type: "ADVANCE" }).state; // DEMONSTRATE
    state = transition(state, { type: "RECOVER" }).state;
    expect(state.phase).toBe(Phase.RECOVERY);
    const back = transition(state, { type: "RECOVERED" }).state;
    expect(back.phase).toBe(Phase.DEMONSTRATE);
  });
});

describe("end + robustness", () => {
  it("END_SESSION is terminal and idempotent", () => {
    let state = initialState();
    state = transition(state, { type: "END_SESSION" }).state;
    expect(state.phase).toBe(Phase.ENDED);
    const r = transition(state, { type: "END_SESSION" });
    expect(r.effects[0]?.kind).toBe("ignored");
  });

  it("never throws on any event from any reachable phase (table exhaustiveness)", () => {
    const events: SessionEvent[] = [
      { type: "ADVANCE" },
      { type: "HARDWARE_INTERRUPT" },
      { type: "RESUME" },
      { type: "PANIC" },
      { type: "RECOVER" },
      { type: "RECOVERED" },
      { type: "POSSESSION_CHANGED", holder: Possession.IDLE },
      { type: "END_SESSION" },
    ];
    const phases = Object.values(Phase);
    for (const target of phases) {
      let state = initialState();
      // best-effort drive toward each phase via ADVANCE; unreachable ones stay where they land
      for (let i = 0; i < 8 && state.phase !== target; i++)
        state = transition(state, { type: "ADVANCE" }).state;
      for (const e of events) {
        expect(() => transition(state, e)).not.toThrow();
      }
    }
  });
});
