/**
 * The teaching-loop state machine (docs/execution-plan.md §2).
 *
 * Two orthogonal axes:
 *   - phase: where in the loop we are (EXPLAIN → DEMONSTRATE → ATTEMPT → FEEDBACK → ADAPT → …)
 *   - possession: who holds the machine (TUTOR / LEARNER / IDLE)
 *
 * The transition function is PURE: (state, event) → { state, effects[] }. Unknown
 * transitions return the state unchanged with an "ignored" effect — a live session
 * never throws on an unexpected event. Phases are a const-object union, not a TS
 * enum, so Node's type-stripping runs the source directly (erasableSyntaxOnly).
 */

export const Phase = {
  INIT: "INIT",
  EXPLAIN: "EXPLAIN",
  DEMONSTRATE: "DEMONSTRATE",
  ATTEMPT: "ATTEMPT",
  FEEDBACK: "FEEDBACK",
  ADAPT: "ADAPT",
  PAUSED: "PAUSED",
  RECOVERY: "RECOVERY",
  ENDED: "ENDED",
} as const;
export type Phase = (typeof Phase)[keyof typeof Phase];

export const Possession = {
  TUTOR: "TUTOR",
  LEARNER: "LEARNER",
  IDLE: "IDLE",
} as const;
export type Possession = (typeof Possession)[keyof typeof Possession];

/** Phases in which the tutor may be driving; a hardware interrupt from these pauses. */
const ACTIVE_PHASES = new Set<Phase>([
  Phase.EXPLAIN,
  Phase.DEMONSTRATE,
  Phase.ATTEMPT,
  Phase.FEEDBACK,
  Phase.ADAPT,
]);

export type SessionEvent =
  | { type: "ADVANCE" }
  | { type: "HARDWARE_INTERRUPT" }
  | { type: "RESUME" }
  | { type: "PANIC" }
  | { type: "RECOVER" }
  | { type: "RECOVERED" }
  | { type: "POSSESSION_CHANGED"; holder: Possession }
  | { type: "END_SESSION" };

export interface SessionState {
  phase: Phase;
  possession: Possession;
  /** Phase to return to on RESUME after a PAUSED/RECOVERY excursion. */
  resumePhase: Phase | null;
}

export type Effect =
  | { kind: "log"; message: string }
  | { kind: "enterPhase"; phase: Phase }
  | { kind: "releasePossession" }
  | { kind: "ignored"; event: SessionEvent["type"]; phase: Phase };

export function initialState(): SessionState {
  return { phase: Phase.INIT, possession: Possession.IDLE, resumePhase: null };
}

/** The linear teaching loop; ADAPT closes back to EXPLAIN for the next concept. */
const LOOP_NEXT: Partial<Record<Phase, Phase>> = {
  [Phase.INIT]: Phase.EXPLAIN,
  [Phase.EXPLAIN]: Phase.DEMONSTRATE,
  [Phase.DEMONSTRATE]: Phase.ATTEMPT,
  [Phase.ATTEMPT]: Phase.FEEDBACK,
  [Phase.FEEDBACK]: Phase.ADAPT,
  [Phase.ADAPT]: Phase.EXPLAIN,
};

export function transition(
  state: SessionState,
  event: SessionEvent,
): { state: SessionState; effects: Effect[] } {
  const ignored = (): { state: SessionState; effects: Effect[] } => ({
    state,
    effects: [{ kind: "ignored", event: event.type, phase: state.phase }],
  });

  switch (event.type) {
    case "END_SESSION": {
      if (state.phase === Phase.ENDED) return ignored();
      return {
        state: { phase: Phase.ENDED, possession: Possession.IDLE, resumePhase: null },
        effects: [{ kind: "releasePossession" }, { kind: "enterPhase", phase: Phase.ENDED }],
      };
    }

    case "ADVANCE": {
      const next = LOOP_NEXT[state.phase];
      if (!next) return ignored();
      return {
        state: { ...state, phase: next },
        effects: [{ kind: "enterPhase", phase: next }],
      };
    }

    case "HARDWARE_INTERRUPT": {
      // Any hardware input during an active phase pauses the tutor and hands the
      // learner control. The <=100ms guarantee lives in the shell's event tap;
      // this models the resulting state so recovery/journal replay is faithful.
      if (!ACTIVE_PHASES.has(state.phase)) return ignored();
      return {
        state: { phase: Phase.PAUSED, possession: Possession.LEARNER, resumePhase: state.phase },
        effects: [
          { kind: "releasePossession" },
          { kind: "enterPhase", phase: Phase.PAUSED },
          { kind: "log", message: `paused from ${state.phase} on hardware interrupt` },
        ],
      };
    }

    case "RESUME": {
      if (state.phase !== Phase.PAUSED || state.resumePhase === null) return ignored();
      const back = state.resumePhase;
      return {
        state: { phase: back, possession: Possession.IDLE, resumePhase: null },
        effects: [{ kind: "enterPhase", phase: back }],
      };
    }

    case "PANIC": {
      // Double-Esc from any live state: full stop, learner has control, no resume.
      if (state.phase === Phase.ENDED) return ignored();
      return {
        state: { phase: Phase.PAUSED, possession: Possession.LEARNER, resumePhase: null },
        effects: [
          { kind: "releasePossession" },
          { kind: "enterPhase", phase: Phase.PAUSED },
          { kind: "log", message: "PANIC: full stop, learner in control" },
        ],
      };
    }

    case "RECOVER": {
      // Crash/desync recovery: re-ground against the world before resuming.
      if (state.phase === Phase.ENDED || state.phase === Phase.RECOVERY) return ignored();
      return {
        state: { ...state, phase: Phase.RECOVERY, resumePhase: state.resumePhase ?? state.phase },
        effects: [{ kind: "enterPhase", phase: Phase.RECOVERY }],
      };
    }

    case "RECOVERED": {
      if (state.phase !== Phase.RECOVERY) return ignored();
      const back = state.resumePhase ?? Phase.EXPLAIN;
      return {
        state: { phase: back, possession: Possession.IDLE, resumePhase: null },
        effects: [{ kind: "enterPhase", phase: back }],
      };
    }

    case "POSSESSION_CHANGED": {
      if (state.possession === event.holder) return ignored();
      return { state: { ...state, possession: event.holder }, effects: [] };
    }

    default: {
      // Exhaustiveness: adding a SessionEvent variant without handling it is a compile error.
      const _never: never = event;
      return { state: _never as SessionState, effects: [] } as never;
    }
  }
}
