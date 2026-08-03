// Tests for the mechanical density verdict. These are the guard on a number that
// decides architecture, so they run in CI with no Accessibility grant and no app:
// synthetic logs in, verdicts out.
//
// Run: node --test shell/Scripts/

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  aggregate,
  ambientCeiling,
  classify,
  clusterReps,
  median,
  parseLog,
  renderAggregate,
  repsFromDriver,
  scoreRun,
  signature,
} from "./ax-density-verdict.mjs";

/** Build a verbose-format log the way axprobe writes one. */
function log({ seconds = 20, events = [] }) {
  const head = `Observing com.example.App (pid 1) for ${seconds}s — drive the app now…\n\n`;
  const body = events
    .map((e) => `  [${String(e.t.toFixed(3)).padStart(8)}] ${e.note}  role=${e.role ?? "-"} title=${e.title ?? "-"}`)
    .join("\n");
  const counts = new Map();
  for (const e of events) counts.set(e.note, (counts.get(e.note) ?? 0) + 1);
  const table = [...counts].map(([n, c]) => `  ${n.padEnd(40)} ${c}`).join("\n");
  const rate = (events.length / seconds).toFixed(2);
  return `${head}${body}\n\n— notification counts —\n${table}\n\n  total: ${events.length}   rate: ${rate} events/sec\n`;
}

/** Three bursts of one notification, 5s apart — the shape a 3-rep driver makes. */
function bursts({ note = "AXValueChanged", title = "-", reps = 3, per = 4, spacing = 5 }) {
  const events = [];
  for (let r = 0; r < reps; r++) {
    for (let i = 0; i < per; i++) {
      events.push({ t: r * spacing + i * 0.02, note, title });
    }
  }
  return events;
}

test("parseLog reads timestamped events and the count summary", () => {
  const parsed = parseLog(log({ events: bursts({}) }));
  assert.equal(parsed.total, 12);
  assert.equal(parsed.seconds, 20);
  assert.equal(parsed.events.length, 12);
  assert.equal(parsed.events[0].note, "AXValueChanged");
});

test("parseLog trusts the total: line over visible event lines", () => {
  // A non-verbose run has counts but no per-event lines.
  const text = "Observing com.example.App (pid 1) for 20s — drive the app now…\n\n— notification counts —\n  AXValueChanged  9\n\n  total: 9   rate: 0.45 events/sec\n";
  const parsed = parseLog(text);
  assert.equal(parsed.total, 9);
  assert.equal(parsed.events.length, 0);
});

test("clusterReps splits on inter-rep silence, not on within-rep chatter", () => {
  assert.equal(clusterReps(bursts({ reps: 3, per: 5 })).length, 3);
  // One continuous burst is one rep however many events it contains.
  assert.equal(clusterReps(bursts({ reps: 1, per: 40 })).length, 1);
});

test("ambientCeiling leaves Poisson slack above the baseline rate", () => {
  assert.equal(ambientCeiling(0, 20), 0);
  assert.ok(ambientCeiling(1, 20) > 20);
});

test("an action at ambient is Silent", () => {
  const result = classify(
    { total: 3, events: [], reps: 3, baselineRate: 1, seconds: 20, gapMs: 250 },
    [],
  );
  assert.equal(result.verdict, "Silent");
});

test("an action firing on every rep with a unique signature is Usable", () => {
  const events = bursts({ reps: 3, per: 4 });
  const result = classify(
    { total: events.length, events, reps: 3, baselineRate: 0, seconds: 20, gapMs: 250 },
    [],
  );
  assert.equal(result.verdict, "Usable");
  assert.equal(result.clusters, 3);
});

test("firing on only some reps is Partial, not Usable", () => {
  const events = bursts({ reps: 2, per: 4 });
  const result = classify(
    { total: events.length, events, reps: 3, baselineRate: 0, seconds: 20, gapMs: 250 },
    [],
  );
  assert.equal(result.verdict, "Partial");
  assert.match(result.reason, /2 bursts for 3 reps/);
});

test("a collision resolvable by an attribute read is Usable*, not Usable", () => {
  // The bar allows "distinct directly OR via one AX attribute read". AXValueChanged
  // means there is a value to read, so this clears the bar — but it is scored in its
  // own tier so the difference stays visible.
  const events = bursts({ note: "AXValueChanged", reps: 5, per: 20 });
  const result = classify(
    { total: events.length, events, reps: 3, baselineRate: 0, seconds: 20, gapMs: 250 },
    ["some other action"],
  );
  assert.equal(result.verdict, "Usable*");
  assert.match(result.reason, /attribute read/);
});

test("a collision with nothing to read is Partial", () => {
  const events = bursts({ note: "AXMenuOpened", reps: 5, per: 2 });
  const result = classify(
    { total: events.length, events, reps: 3, baselineRate: 0, seconds: 20, gapMs: 250 },
    ["some other action"],
  );
  assert.equal(result.verdict, "Partial");
  assert.match(result.reason, /nothing to read/);
});

test("counts without --verbose cannot prove per-rep firing", () => {
  const result = classify(
    { total: 90, events: [], reps: 3, baselineRate: 0, seconds: 20, gapMs: 250 },
    [],
  );
  assert.equal(result.verdict, "Partial");
  assert.match(result.reason, /--verbose/);
});

test("signature separates commands by AXMenuItemSelected title", () => {
  const copy = signature([{ note: "AXMenuItemSelected", title: "Copy" }]);
  const paste = signature([{ note: "AXMenuItemSelected", title: "Paste" }]);
  assert.notEqual(copy, paste);
  assert.match(copy, /menu\(Copy\)/);
});

test("scoreRun separates strict distinctness from the bar as written", () => {
  // Two actions whose notification traces are identical: nothing but an attribute
  // read can tell them apart, so neither is strictly Usable.
  const shared = bursts({ note: "AXValueChanged", reps: 3, per: 4 });
  const result = scoreRun({
    baseline: { rate: 0, seconds: 30 },
    actions: [
      { name: "bold toggle", events: shared, total: shared.length, reps: 3, seconds: 20 },
      { name: "italic toggle", events: shared, total: shared.length, reps: 3, seconds: 20 },
      {
        name: "copy",
        events: bursts({ note: "AXMenuItemSelected", title: "Copy", reps: 3, per: 1 }),
        total: 3,
        reps: 3,
        seconds: 20,
      },
    ],
  });
  assert.equal(result.strict, 1, "only the unique-signature action is strictly distinct");
  assert.equal(result.counted, 3, "the colliding pair still clears the bar via an attribute read");
  assert.equal(result.scored[0].verdict, "Usable*");
  assert.equal(result.scored[1].verdict, "Usable*");
  assert.equal(result.scored[2].verdict, "Usable");
});

test("repsFromDriver reads the header and defaults to 3", () => {
  assert.equal(repsFromDriver("# name: x\n# reps: 5\nactivate\n"), 5);
  assert.equal(repsFromDriver("# name: x\nactivate\n"), 3);
});

// ---- Aggregation across repeated runs ----
//
// These guard the correction to the original spike: one run decided the architecture
// and a second run of the same protocol disagreed by seventeen points.

/** A run in the shape scoreRun returns, built from an ordered {action: verdict} map. */
function run(verdicts) {
  const scored = Object.entries(verdicts).map(([name, verdict]) => ({ name, verdict }));
  const strict = scored.filter((s) => s.verdict === "Usable").length;
  const counted = scored.filter((s) => s.verdict === "Usable" || s.verdict === "Usable*").length;
  return { scored, usable: counted, strict, counted, count: scored.length };
}

/** `n` actions of one verdict, then the rest Partial — a run of a given score. */
function runOfScore(usableCount, total = 20, verdict = "Usable") {
  const verdicts = {};
  for (let i = 1; i <= total; i++) verdicts[`action ${i}`] = i <= usableCount ? verdict : "Partial";
  return run(verdicts);
}

test("median handles odd and even run counts", () => {
  assert.equal(median([17, 14, 20]), 17);
  assert.equal(median([0, 17]), 8.5, "an even count averages the two middle values");
  assert.equal(median([20, 14, 17, 19]), 18);
  assert.equal(median([]), null);
});

test("an action Usable in every run is stable; one Usable in some runs is not", () => {
  const agg = aggregate([
    run({ bold: "Usable", "align center": "Usable" }),
    run({ bold: "Usable", "align center": "Partial" }),
    run({ bold: "Usable*", "align center": "Silent" }),
  ]);
  const [bold, align] = agg.actions;
  assert.equal(bold.usableIn, 3);
  assert.equal(bold.stable, true, "Usable* is still Usable under the bar as written");
  assert.equal(bold.flapping, false);
  assert.equal(align.usableIn, 1);
  assert.equal(align.stable, false, "Usable in 1 of 3 runs is a coin flip, not a passing action");
  assert.equal(align.flapping, true);
  assert.deepEqual(agg.flapping.map((a) => a.name), ["align center"]);
  assert.equal(agg.alwaysUsable, 1);
  assert.equal(agg.everUsable, 2);
});

test("an action missing from a run is 'absent', not silently Usable", () => {
  const agg = aggregate([run({ bold: "Usable", undo: "Usable" }), run({ bold: "Usable" })]);
  const undo = agg.actions.find((a) => a.name === "undo");
  assert.deepEqual(undo.verdicts, ["Usable", "absent"]);
  assert.equal(undo.usableIn, 1);
});

test("runs that bracket the bar are UNDECIDED, not averaged into an answer", () => {
  // The committed pair: one run whose logs cannot support the per-rep criterion, one
  // that scores exactly at the bar. No action is Usable in both.
  const agg = aggregate([runOfScore(0), runOfScore(17)]);
  assert.equal(agg.verdict, "UNDECIDED");
  assert.equal(agg.median, 8.5);
  assert.equal(agg.min, 0);
  assert.equal(agg.max, 17);
  assert.equal(agg.spread, 17);
  assert.equal(agg.alwaysUsable, 0);
  assert.equal(agg.everUsable, 17);
  assert.match(agg.reasons.join(" "), /depends on which run you believe/);
  assert.equal(agg.flapping.length, 17, "every action that scored disagreed between runs");
});

test("a median sitting on the bar is UNDECIDED — one flapping action is worth a point", () => {
  const agg = aggregate([runOfScore(17), runOfScore(17), runOfScore(17)]);
  assert.equal(agg.alwaysUsable, 17, "the same actions passed every time");
  assert.equal(agg.verdict, "UNDECIDED");
  assert.match(agg.reasons.join(" "), /within 1 of the 17 bar/);
  // 18 is still inside the band; 19 clears it.
  assert.equal(aggregate([runOfScore(18), runOfScore(18)]).verdict, "UNDECIDED");
  assert.equal(aggregate([runOfScore(19), runOfScore(19)]).verdict, "PASS");
});

test("a stable score clear of the band passes; one clear below fails", () => {
  const pass = aggregate([runOfScore(20), runOfScore(19), runOfScore(20)]);
  assert.equal(pass.verdict, "PASS");
  assert.equal(pass.median, 20);
  const fail = aggregate([runOfScore(9), runOfScore(11), runOfScore(10)]);
  assert.equal(fail.verdict, "FAIL");
  assert.equal(fail.median, 10);
  assert.equal(fail.reasons.length, 0);
});

test("aggregation reports both tiers separately, as the single-run scorer does", () => {
  const agg = aggregate([
    run({ a: "Usable", b: "Usable*" }),
    run({ a: "Usable", b: "Usable*" }),
  ]);
  assert.deepEqual(agg.scores, [2, 2]);
  assert.deepEqual(agg.strictScores, [1, 1]);
  assert.equal(agg.strictMedian, 1);
});

test("the rendered report names the flapping actions rather than burying them", () => {
  const text = renderAggregate(aggregate([runOfScore(0), runOfScore(17)], { labels: ["run-a", "run-b"] }));
  assert.match(text, /VERDICT: UNDECIDED/);
  assert.match(text, /17\/20 actions changed verdict between runs/);
  assert.match(text, /action 1 — Usable in 1\/2/);
  assert.match(text, /median \*\*8\.5\/20\*\*/);
  assert.match(text, /run-a \| run-b/);
});

test("a non-canonical action count is called out, not silently rescaled", () => {
  const text = renderAggregate(aggregate([run({ a: "Usable" }), run({ a: "Usable" })]));
  assert.match(text, /bar is stated as >=17\/20 canonical actions; this set has 1/);
});

test("aggregating a single run still applies the bar to that run", () => {
  const agg = aggregate([runOfScore(20)]);
  assert.equal(agg.verdict, "PASS");
  assert.equal(agg.alwaysUsable, 20);
  assert.equal(agg.flapping.length, 0);
});
