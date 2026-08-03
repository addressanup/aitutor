#!/usr/bin/env node
// Mechanical density verdict (delivery-plan §15 Task 2, made reproducible).
//
// The density bar — ">=17/20 actions emit usable AXObserver notifications" — decides
// whether observation is observer-primary or falls back to hit-testing, and reprices
// the look budget. A bar that gates architecture should not be a column somebody
// types in by eye: a second reader, or a second machine, must be able to recompute it
// from the committed logs and get the same answer.
//
// The results doc defines Usable as "fires every rep, attributable above baseline,
// semantically distinct". All three are computable:
//
//   above ambient   — the action window carries more than the hands-off baseline rate
//                     predicts, with Poisson slack so a quiet app is not flattered
//   fires every rep — event timestamps cluster into at least as many bursts as the
//                     driver performed repetitions (drivers sleep between reps, so
//                     the silences are real boundaries)
//   distinct        — the action's notification signature is unique across the set.
//                     Signature collision IS the operational meaning of "the observer
//                     cannot tell action A from action B", so it is the honest test.
//
// Usable = all three. Usable* = fires every rep but shares a signature with another
// action, separable only by an AX attribute read — which the bar's own wording
// allows, so it counts. Partial = does not fire on every rep, or collides with
// nothing readable to separate it. Silent = indistinguishable from ambient.
//
// Usage:  ax-density-verdict.mjs <run-dir> [--drivers <dir>] [--gap-ms 250] [--json]

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { basename, join } from "node:path";

export const DEFAULT_GAP_MS = 250;
export const DEFAULT_REPS = 3;

/** Parse a verbose axprobe log into events, plus its trailing count summary. */
export function parseLog(text) {
  const events = [];
  let total = null;
  let rate = null;
  let seconds = null;
  for (const line of text.split("\n")) {
    const ev = line.match(/^\s*\[\s*([\d.]+)\]\s+(\S+)\s+role=(\S*)\s+title=(.*?)\s*$/);
    if (ev) {
      events.push({ t: Number(ev[1]), note: ev[2], role: ev[3], title: ev[4] });
      continue;
    }
    const totals = line.match(/total:\s*(\d+)\s+rate:\s*([\d.]+)/);
    if (totals) {
      total = Number(totals[1]);
      rate = Number(totals[2]);
      continue;
    }
    const observing = line.match(/for\s+(\d+)s\s+—/);
    if (observing) seconds = Number(observing[1]);
  }
  // `total:` is authoritative — it counts every event, while only --verbose runs
  // print the per-event lines this parser can see.
  if (total === null) total = events.length;
  if (seconds === null && rate > 0) seconds = Math.round(total / rate);
  return { events, total, rate, seconds };
}

/** Split event times into bursts separated by at least `gapMs` of silence. */
export function clusterReps(events, gapMs = DEFAULT_GAP_MS) {
  if (events.length === 0) return [];
  const times = events.map((e) => e.t).sort((a, b) => a - b);
  const clusters = [];
  let start = times[0];
  let prev = times[0];
  for (const t of times.slice(1)) {
    if ((t - prev) * 1000 > gapMs) {
      clusters.push({ start, end: prev });
      start = t;
    }
    prev = t;
  }
  clusters.push({ start, end: prev });
  return clusters;
}

/**
 * A stable signature for what the observer saw. Notification types always; for
 * AXMenuItemSelected the command titles too, since those carry the semantics that
 * make one command distinguishable from another.
 */
export function signature(events) {
  const types = new Set();
  const titles = new Set();
  for (const e of events) {
    types.add(e.note);
    if (e.note === "AXMenuItemSelected" && e.title && e.title !== "-") titles.add(e.title);
  }
  const parts = [...types].sort();
  if (titles.size > 0) parts.push(`menu(${[...titles].sort().join("|")})`);
  return parts.join("+");
}

/** Poisson-ish upper bound on ambient noise over a window of `seconds`. */
export function ambientCeiling(baselineRate, seconds) {
  const expected = baselineRate * seconds;
  return expected + 3 * Math.sqrt(expected);
}

/**
 * Classify one action. `collides` is supplied by the caller, which alone can see
 * every action's signature.
 */
export function classify({ total, events, reps, baselineRate, seconds, gapMs }, collides) {
  const ceiling = ambientCeiling(baselineRate, seconds);
  const aboveAmbient = total > ceiling;
  if (!aboveAmbient) {
    return { verdict: "Silent", aboveAmbient, clusters: 0, reason: `${total} events vs ambient ceiling ${ceiling.toFixed(1)}` };
  }
  const clusters = clusterReps(events, gapMs).length;
  // Without --verbose there are no per-event lines, so rep clustering cannot be
  // evaluated; say so rather than silently passing or failing the criterion.
  if (events.length === 0) {
    return { verdict: "Partial", aboveAmbient, clusters: 0, reason: "no per-event timestamps in log (run axprobe with --verbose)" };
  }
  const firesEveryRep = clusters >= reps;
  if (!firesEveryRep) {
    return { verdict: "Partial", aboveAmbient, clusters, reason: `${clusters} bursts for ${reps} reps` };
  }
  if (collides.length > 0) {
    // The bar's own wording is "semantically distinct (directly OR via one AX
    // attribute read)". A collision means the notification types alone cannot
    // separate these actions — but if the trace carries AXValueChanged there is a
    // value to read, which is the read the observation layer's adapter-poll channel
    // performs anyway. That is Usable under the stated definition, so it is scored
    // as its own tier rather than hidden inside either Usable or Partial.
    const readable = events.some((e) => e.note === "AXValueChanged" || e.note === "AXSelectedTextChanged");
    if (readable) {
      return {
        verdict: "Usable*",
        aboveAmbient,
        clusters,
        reason: `fires every rep; separable from ${collides.join(", ")} only by an attribute read`,
      };
    }
    return { verdict: "Partial", aboveAmbient, clusters, reason: `signature collides with ${collides.join(", ")}, nothing to read` };
  }
  return { verdict: "Usable", aboveAmbient, clusters, reason: `${clusters} bursts >= ${reps} reps, signature unique` };
}

/** Read `# reps: N` from a driver file, defaulting when absent. */
export function repsFromDriver(text) {
  const m = text.match(/^#\s*reps:\s*(\d+)/m);
  return m ? Number(m[1]) : DEFAULT_REPS;
}

export function scoreRun({ baseline, actions, gapMs = DEFAULT_GAP_MS }) {
  const signatures = actions.map((a) => signature(a.events));
  const scored = actions.map((action, i) => {
    const collides = actions
      .map((other, j) => (j !== i && signatures[j] === signatures[i] && signatures[i] !== "" ? other.name : null))
      .filter(Boolean);
    const result = classify(
      {
        total: action.total,
        events: action.events,
        reps: action.reps,
        baselineRate: baseline.rate ?? 0,
        seconds: action.seconds,
        gapMs,
      },
      collides,
    );
    return { ...action, signature: signatures[i], ...result };
  });
  // Strict = signature unique on its own. Counted = the bar as written, which allows
  // one AX attribute read to separate two actions. Both are reported, always.
  const strict = scored.filter((s) => s.verdict === "Usable").length;
  const counted = scored.filter((s) => s.verdict === "Usable" || s.verdict === "Usable*").length;
  return { scored, usable: counted, strict, counted, count: scored.length };
}

function loadRun(runDir, driversDir, gapMs) {
  const baselinePath = join(runDir, "00-baseline.log");
  const baseline = existsSync(baselinePath)
    ? parseLog(readFileSync(baselinePath, "utf8"))
    : { rate: 0, total: 0, seconds: 0, events: [] };

  const driverReps = new Map();
  if (driversDir && existsSync(driversDir)) {
    for (const f of readdirSync(driversDir).filter((f) => f.endsWith(".axd")).sort()) {
      const text = readFileSync(join(driversDir, f), "utf8");
      const name = text.match(/^#\s*name:\s*(.+)$/m)?.[1]?.trim() ?? basename(f, ".axd");
      driverReps.set(name, repsFromDriver(text));
    }
  }

  const actions = readdirSync(runDir)
    .filter((f) => f.endsWith(".log") && !f.startsWith("00-"))
    .sort()
    .map((f) => {
      const parsed = parseLog(readFileSync(join(runDir, f), "utf8"));
      const name = basename(f, ".log").replace(/^\d+-/, "").replace(/-/g, " ");
      let reps = DEFAULT_REPS;
      for (const [driverName, n] of driverReps) {
        if (driverName.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim() === name) reps = n;
      }
      return { file: f, name, reps, ...parsed };
    });

  return scoreRun({ baseline, actions, gapMs });
}

export function renderTable(result) {
  const lines = [
    "| # | Action | Events | Rate (ev/s) | Bursts/Reps | Signature | Verdict | Why |",
    "|---|--------|--------|-------------|-------------|-----------|---------|-----|",
  ];
  result.scored.forEach((s, i) => {
    const rate = s.seconds ? (s.total / s.seconds).toFixed(2) : "—";
    lines.push(
      `| ${i + 1} | ${s.name} | ${s.total} | ${rate} | ${s.clusters}/${s.reps} | \`${s.signature || "—"}\` | **${s.verdict}** | ${s.reason} |`,
    );
  });
  return lines.join("\n");
}

// ---- CLI ----
const isMain = process.argv[1] && import.meta.url.endsWith(basename(process.argv[1]));
if (isMain) {
  const args = process.argv.slice(2);
  const runDir = args.find((a) => !a.startsWith("--"));
  const flag = (name, fallback) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : fallback;
  };
  if (!runDir) {
    console.error("usage: ax-density-verdict.mjs <run-dir> [--drivers <dir>] [--gap-ms 250] [--json]");
    process.exit(2);
  }
  const result = loadRun(runDir, flag("drivers", null), Number(flag("gap-ms", DEFAULT_GAP_MS)));
  if (args.includes("--json")) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(renderTable(result));
    console.log(
      `\n**Mechanical score: ${result.counted}/${result.count} Usable** ` +
        `(${result.strict}/${result.count} distinct on notification types alone; ` +
        `${result.counted - result.strict} separable only by an AX attribute read). ` +
        `Bar: >=17/20 ⇒ observer-primary.`,
    );
  }
}
