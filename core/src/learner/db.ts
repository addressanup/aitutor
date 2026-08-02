import { DatabaseSync } from "node:sqlite";

/**
 * The ONLY file that touches SQLite. Uses Node's built-in node:sqlite
 * (DatabaseSync) — zero native modules, nothing to compile on a learner's Mac.
 * If loadable extensions or measured perf ever demand it, swap to better-sqlite3
 * here; the synchronous API shape matches, so the blast radius is this file.
 *
 * Schema versioned via PRAGMA user_version.
 */

export type DB = DatabaseSync;

const SCHEMA_V1 = `
CREATE TABLE IF NOT EXISTS journal (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  TEXT    NOT NULL,
  seq         INTEGER NOT NULL,
  ts_ms       INTEGER NOT NULL,
  kind        TEXT    NOT NULL,
  payload_json TEXT   NOT NULL,
  prev_hash   TEXT    NOT NULL,
  hash        TEXT    NOT NULL,
  UNIQUE(session_id, seq)
);

CREATE TABLE IF NOT EXISTS skill_mastery (
  skill_id       TEXT PRIMARY KEY,
  log_odds       REAL NOT NULL DEFAULT 0,
  evidence_count INTEGER NOT NULL DEFAULT 0,
  updated_ms     INTEGER NOT NULL DEFAULT 0
);
`;

export function openDatabase(path: string): DB {
  const db = new DatabaseSync(path);
  db.exec("PRAGMA journal_mode = WAL;");
  db.exec("PRAGMA foreign_keys = ON;");
  migrate(db);
  return db;
}

function migrate(db: DB): void {
  const row = db.prepare("PRAGMA user_version").get() as { user_version: number } | undefined;
  const version = row?.user_version ?? 0;
  if (version < 1) {
    db.exec(SCHEMA_V1);
    db.exec("PRAGMA user_version = 1;");
  }
}
