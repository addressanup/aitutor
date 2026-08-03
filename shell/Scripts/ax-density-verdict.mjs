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
// One run is not a measurement. Two runs of this identical protocol, same machine,
// ninety minutes apart, disagreed by seventeen points; individual actions swung from
// 67 events to 2. So the tool also aggregates N run directories and applies the bar to
// the median, reporting per-action stability (Usable in how many of N) and refusing to
// call a result that the runs themselves do not agree on. See "the finding that matters
// most" in docs/notes/spike-ax-textedit-results.md.
//
// Usage:  ax-density-verdict.mjs <run-dir>... [--drivers <dir>] [--gap-ms 250]
//                                [--target 17] [--band 1] [--json]
//
// With two or more run dirs the exit status carries the verdict: 0 PASS, 1 FAIL or
// UNDECIDED. Callers that only want the report should ignore it — but a pipeline that
// treats a green exit as "observer-primary is settled" then cannot be quietly wrong.

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { basename, join } from "node:path";

export const DEFAULT_GAP_MS = 250;
export const DEFAULT_REPS = 3;
export const DEFAULT_TARGET = 17;
// Half the observed run-to-run spread would be generous; one point is the minimum
// honesty, since a single action flipping verdict moves the score by exactly one.
export const DEFAULT_BAND = 1;

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

/** Clears the bar as written — either tier counts. */
export function isUsable(verdict) {
  return verdict === "Usable" || verdict === "Usable*";
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
  const counted = scored.filter((s) => isUsable(s.verdict)).length;
  return { scored, usable: counted, strict, counted, count: scored.length };
}

// ---- Aggregation across repeated runs ----

/** Ordinary median; even N averages the two middle values, so it can be fractional. */
export function median(values) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length >> 1;
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

/**
 * Fold N scored runs into one answer.
 *
 * The load-bearing number is not the mean score — averaging two runs that disagree
 * manufactures a confidence neither run has. It is per-action stability: an action
 * Usable in 1 of 3 runs is not a passing action, it is a coin flip. So the aggregate
 * brackets the truth between the pessimistic reading (Usable in EVERY run) and the
 * optimistic one (Usable in ANY run). If the bar falls inside that bracket, the runs
 * literally do not agree on the architecture decision and the honest answer is
 * UNDECIDED — as it is when the median lands within the band of the bar, since a
 * single flapping action moves the score by a point.
 */
export function aggregate(runs, { target = DEFAULT_TARGET, band = DEFAULT_BAND, labels = [] } = {}) {
  const n = runs.length;
  const order = [];
  const byName = new Map();
  runs.forEach((run, i) => {
    for (const s of run.scored) {
      if (!byName.has(s.name)) {
        byName.set(s.name, new Array(n).fill("absent"));
        order.push(s.name);
      }
      byName.get(s.name)[i] = s.verdict;
    }
  });

  const actions = order.map((name) => {
    const verdicts = byName.get(name);
    const usableIn = verdicts.filter(isUsable).length;
    return { name, verdicts, usableIn, runs: n, stable: usableIn === n, flapping: usableIn > 0 && usableIn < n };
  });

  const count = actions.length;
  const scores = runs.map((r) => r.counted);
  const strictScores = runs.map((r) => r.strict);
  const med = median(scores);
  const min = scores.length ? Math.min(...scores) : null;
  const max = scores.length ? Math.max(...scores) : null;

  // The bracket. `alwaysUsable` is what survives every run; `everUsable` is what the
  // most generous cherry-pick of runs could claim.
  const alwaysUsable = actions.filter((a) => a.stable).length;
  const everUsable = actions.filter((a) => a.usableIn > 0).length;
  const flapping = actions.filter((a) => a.flapping);

  const undecided = [];
  if (alwaysUsable < target && everUsable >= target) {
    undecided.push(
      `${alwaysUsable}/${count} actions were Usable in EVERY run and ${everUsable}/${count} in at least one — ` +
        `the ${target} bar falls inside that bracket, so the verdict depends on which run you believe`,
    );
  }
  if (med !== null && Math.abs(med - target) <= band) {
    undecided.push(
      `median ${fmt(med)}/${count} is within ${band} of the ${target} bar — inside this measurement's own noise`,
    );
  }
  const verdict = undecided.length > 0 ? "UNDECIDED" : med >= target ? "PASS" : "FAIL";

  // Deliberately no raw runs in the result: N runs of per-event traces make the JSON
  // unreadable, and everything the decision needs is summarized here.
  return {
    labels: labels.length === n ? labels : runs.map((_, i) => `run-${i + 1}`),
    n,
    count,
    actions,
    flapping,
    scores,
    strictScores,
    median: med,
    strictMedian: median(strictScores),
    min,
    max,
    spread: min === null ? null : max - min,
    alwaysUsable,
    everUsable,
    target,
    band,
    verdict,
    reasons: undecided,
  };
}

/** Integers print as integers; only an even-N median earns a decimal point. */
function fmt(x) {
  return Number.isInteger(x) ? String(x) : x.toFixed(1);
}

export function renderAggregate(agg) {
  const lines = [
    `| # | Action | Usable in | ${agg.labels.join(" | ")} |`,
    `|---|--------|-----------|${agg.labels.map(() => "---").join("|")}|`,
  ];
  agg.actions.forEach((a, i) => {
    // Mark the flappers in the table itself; they are the reason for the verdict.
    const flag = a.flapping ? " ⚠" : "";
    lines.push(
      `| ${i + 1} | ${a.name} | **${a.usableIn}/${a.runs}**${flag} | ${a.verdicts.join(" | ")} |`,
    );
  });

  lines.push("");
  lines.push(
    `Per-run score (counted): ${agg.scores.join(", ")} — ` +
      `median **${fmt(agg.median)}/${agg.count}**, min ${agg.min}, max ${agg.max}, spread ${agg.spread}.`,
  );
  lines.push(
    `Per-run score (strict): ${agg.strictScores.join(", ")} — median ${fmt(agg.strictMedian)}/${agg.count}.`,
  );
  lines.push(
    `Usable in EVERY run: **${agg.alwaysUsable}/${agg.count}**. ` +
      `Usable in at least one run: **${agg.everUsable}/${agg.count}**.`,
  );
  if (agg.flapping.length > 0) {
    // Say it loudly. A quiet average of disagreeing runs is how the original
    // single-run 20/20 got written down as a fact.
    lines.push("");
    lines.push(`⚠ **${agg.flapping.length}/${agg.count} actions changed verdict between runs:**`);
    for (const a of agg.flapping) lines.push(`  - ${a.name} — Usable in ${a.usableIn}/${a.runs} (${a.verdicts.join(", ")})`);
  }

  if (agg.count !== 20) {
    // The bar is worded against a 20-action canonical set. Rescaling it silently for a
    // different set would invent a threshold nobody agreed to, so say so instead.
    lines.push("");
    lines.push(
      `⚠ The bar is stated as >=${DEFAULT_TARGET}/20 canonical actions; this set has ${agg.count}. ` +
        `Pass --target to state the bar for this set.`,
    );
  }

  lines.push("");
  const headline = `**VERDICT: ${agg.verdict}** (bar: >=${agg.target}/${agg.count} ⇒ observer-primary)`;
  if (agg.verdict === "UNDECIDED") {
    lines.push(`${headline} — this measurement cannot decide the architecture:`);
    for (const r of agg.reasons) lines.push(`  - ${r}`);
    lines.push(`  Run more repetitions before spending the decision.`);
  } else {
    lines.push(`${headline} — median ${fmt(agg.median)}/${agg.count} over ${agg.n} run(s), stable floor ${agg.alwaysUsable}/${agg.count}.`);
  }
  return lines.join("\n");
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
const VALUED_FLAGS = new Set(["--drivers", "--gap-ms", "--target", "--band"]);
if (isMain) {
  const args = process.argv.slice(2);
  const flag = (name, fallback) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : fallback;
  };
  // Positional = anything that is neither a flag nor a flag's value, so run dirs may
  // appear on either side of the flags.
  const runDirs = args.filter((a, i) => !a.startsWith("--") && !VALUED_FLAGS.has(args[i - 1]));
  if (runDirs.length === 0) {
    console.error(
      "usage: ax-density-verdict.mjs <run-dir>... [--drivers <dir>] [--gap-ms 250] [--target 17] [--band 1] [--json]",
    );
    process.exit(2);
  }
  const driversDir = flag("drivers", null);
  const gapMs = Number(flag("gap-ms", DEFAULT_GAP_MS));
  const results = runDirs.map((d) => loadRun(d, driversDir, gapMs));

  // One directory keeps the original single-run report verbatim — the summary.md
  // writer and the results doc both quote it.
  if (results.length === 1) {
    const result = results[0];
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
  } else {
    const agg = aggregate(results, {
      target: Number(flag("target", DEFAULT_TARGET)),
      band: Number(flag("band", DEFAULT_BAND)),
      labels: runDirs.map((d) => basename(d.replace(/\/+$/, ""))),
    });
    if (args.includes("--json")) {
      console.log(JSON.stringify(agg, null, 2));
    } else {
      console.log(renderAggregate(agg));
    }
    // A verdict nobody can act on should not exit 0 into a green pipeline.
    if (agg.verdict !== "PASS") process.exitCode = 1;
  }
}
