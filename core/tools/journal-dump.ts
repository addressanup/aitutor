import { existsSync } from "node:fs";
import { join } from "node:path";
import { openDatabase } from "../src/learner/db.ts";
import { readRows, verifyChain } from "../src/session/journal.ts";

/**
 * Prints the hash-chained journal rows and verifies the chain, for `make journal-dump`.
 * Reads the dev db at core/.data/learner.db (populated once the session engine writes
 * to it). At scaffold this seeds a demo session so the target has something to show.
 */
const DB_PATH = join(import.meta.dirname, "..", ".data", "learner.db");

if (!existsSync(join(import.meta.dirname, "..", ".data"))) {
  // node:fs mkdir without importing more surface
  const { mkdirSync } = await import("node:fs");
  mkdirSync(join(import.meta.dirname, "..", ".data"), { recursive: true });
}

const db = openDatabase(DB_PATH);
const sessionId = "demo-session";

// Seed a short session if empty, so the dump is never blank at scaffold.
const existing = readRows(db, sessionId);
if (existing.length === 0) {
  const { Journal } = await import("../src/session/journal.ts");
  const j = new Journal(db, sessionId);
  let t = Date.now();
  for (const e of [
    { type: "ADVANCE" as const },
    { type: "ADVANCE" as const },
    { type: "HARDWARE_INTERRUPT" as const },
    { type: "RESUME" as const },
  ]) {
    j.append(e, t++);
  }
}

const rows = readRows(db, sessionId);
console.log(`journal for session "${sessionId}" — ${rows.length} rows\n`);
for (const r of rows) {
  console.log(
    `#${r.seq}  ${r.kind.padEnd(18)}  ${r.hash.slice(0, 12)}…  (prev ${r.prevHash.slice(0, 8)}…)`,
  );
}
console.log(`\nchain valid: ${verifyChain(db, sessionId)}`);
