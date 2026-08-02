import { createHash } from "node:crypto";
import type { DB } from "../learner/db.ts";
import { initialState, type SessionEvent, type SessionState, transition } from "./machine.ts";

/**
 * Append-only, hash-chained session journal (docs/execution-plan.md §2, §4).
 * Each row's hash covers the previous hash, so tampering or a gap breaks the chain
 * — the same chain the future "What your tutor did" surface inherits for free.
 * replay() folds the journal through the pure transition() to rebuild state after
 * a crash, without re-executing any side effects.
 */

export const GENESIS_HASH = "0".repeat(64);

export interface JournalRow {
  seq: number;
  tsMs: number;
  kind: string;
  payloadJson: string;
  prevHash: string;
  hash: string;
}

function rowHash(
  prevHash: string,
  sessionId: string,
  seq: number,
  tsMs: number,
  kind: string,
  payloadJson: string,
): string {
  return createHash("sha256")
    .update(`${prevHash}\n${sessionId}\n${seq}\n${tsMs}\n${kind}\n${payloadJson}`)
    .digest("hex");
}

export class Journal {
  private seq: number;
  private lastHash: string;

  private readonly db: DB;
  private readonly sessionId: string;

  constructor(db: DB, sessionId: string) {
    this.db = db;
    this.sessionId = sessionId;
    const row = db
      .prepare("SELECT seq, hash FROM journal WHERE session_id = ? ORDER BY seq DESC LIMIT 1")
      .get(sessionId) as { seq: number; hash: string } | undefined;
    this.seq = row ? row.seq : -1;
    this.lastHash = row ? row.hash : GENESIS_HASH;
  }

  /** Append one event; returns the stored row. */
  append(event: SessionEvent, tsMs: number): JournalRow {
    const seq = ++this.seq;
    const kind = event.type;
    const payloadJson = JSON.stringify(event);
    const prevHash = this.lastHash;
    const hash = rowHash(prevHash, this.sessionId, seq, tsMs, kind, payloadJson);
    this.db
      .prepare(
        "INSERT INTO journal (session_id, seq, ts_ms, kind, payload_json, prev_hash, hash) VALUES (?, ?, ?, ?, ?, ?, ?)",
      )
      .run(this.sessionId, seq, tsMs, kind, payloadJson, prevHash, hash);
    this.lastHash = hash;
    return { seq, tsMs, kind, payloadJson, prevHash, hash };
  }
}

export function readRows(db: DB, sessionId: string): JournalRow[] {
  const rows = db
    .prepare(
      "SELECT seq, ts_ms, kind, payload_json, prev_hash, hash FROM journal WHERE session_id = ? ORDER BY seq ASC",
    )
    .all(sessionId) as Array<{
    seq: number;
    ts_ms: number;
    kind: string;
    payload_json: string;
    prev_hash: string;
    hash: string;
  }>;
  return rows.map((r) => ({
    seq: r.seq,
    tsMs: r.ts_ms,
    kind: r.kind,
    payloadJson: r.payload_json,
    prevHash: r.prev_hash,
    hash: r.hash,
  }));
}

/** Verify the hash chain is intact and correctly linked. */
export function verifyChain(db: DB, sessionId: string): boolean {
  let prev = GENESIS_HASH;
  for (const r of readRows(db, sessionId)) {
    if (r.prevHash !== prev) return false;
    const expected = rowHash(r.prevHash, sessionId, r.seq, r.tsMs, r.kind, r.payloadJson);
    if (expected !== r.hash) return false;
    prev = r.hash;
  }
  return true;
}

/** Fold the journal through the pure transition to rebuild session state. */
export function replay(db: DB, sessionId: string): SessionState {
  let state = initialState();
  for (const r of readRows(db, sessionId)) {
    const event = JSON.parse(r.payloadJson) as SessionEvent;
    state = transition(state, event).state;
  }
  return state;
}
