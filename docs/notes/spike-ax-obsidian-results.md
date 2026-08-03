# AX density spike — results: md.obsidian (Electron / Chromium target)

**Date:** 2026-08-03 · **Machine:** dev Mac (Darwin 25.5.0, Apple Silicon) · **Obsidian 1.13.4** · **Mode:** fully headless — `axdrive` performs, `axprobe` observes, `shell/Scripts/ax-density-run.sh --drivers spikes/drivers/md.obsidian --enable-ax --repeat`.
**Raw numbers:** `docs/notes/spike-ax-runs/md-obsidian-20260803-112911/` (run 1) and `md-obsidian-20260803-113918/run-{1,2}/` (runs 2–3). Reproduce the table by rerunning `shell/Scripts/ax-density-verdict.mjs` over those three directories.

## Why this target

The density bar decides whether observation is observer-primary or the hit-testing fallback
becomes primary, and it is a **per-app** question. TextEdit answered it for plain AppKit
text and could never answer it for a custom canvas. Obsidian is Electron/Chromium,
local-first, and needs no account — so it answers the architecturally decisive version of
the question ("does a browser-backed app expose AX a tutor can observe?") without the
account risk or sign-in blocking that the Figma run carries.

It is a **hard-mode datapoint, not the wedge verdict.** A sub-bar score here does not by
itself open the look-budget re-derivation ticket, whose trigger is the wedge app's score.

## Result — UNDECIDED

Three runs of the identical protocol, back to back on one machine:

| | Run 1 | Run 2 | Run 3 | Median |
|---|---|---|---|---|
| Counted (bar's own definition, attribute read allowed) | 15/20 | 17/20 | 18/20 | **17/20** |
| Strict (distinct on notification type alone) | 4/20 | 3/20 | 4/20 | **4/20** |

- Usable in **every** run: **15/20** · Usable in **at least one** run: **18/20**
- 3/20 actions changed verdict between runs: *type text* (2/3), *insert wiki link* (2/3),
  *split pane* (1/3)

**Verdict: UNDECIDED.** The bar is ≥17/20; the median is exactly 17, and 15–18 brackets it.
Under the plan's rule — a median of ≥3 runs, with 16–18 treated as UNDECIDED — this
measurement **cannot decide the architecture for this app**. That is the correct outcome,
not a failure of the run: the spread is real, and a single run would have reported 15
(fail), 17 (pass), or 18 (pass) depending purely on which afternoon it happened.

This is the median rule's first application, and it caught exactly what it was written for.

## What Chromium actually exposes — the fear was wrong, the problem is different

The worry going in was that a browser-backed app would be opaque to AX. **It is not.**
With `AXManualAccessibility` set, Obsidian emits copiously — 500 events in a 20 s window
for heading-insertion, 341 for bullet lists, 272 for a code fence, 183 for find-in-note.
Ambient baseline is 0. There is no shortage of signal.

The problem is **distinguishability**, and it is severe:

- **Strict median 4/20.** Only four actions have a notification signature unique across the
  set. The rest collide.
- The dominant collision is `AXSelectedTextChanged + AXTitleChanged + AXValueChanged`,
  shared by *code fence*, *select all*, *delete characters*, *redo* and others. To an
  observer watching notification types alone, those actions are the same event.
- 11–14 of the 20 clear the bar **only** via the attribute-read allowance.

So for a browser-backed target the observation layer does not get semantics from the
notification stream; it gets a **change signal** plus an obligation to read state. Every
such action costs an AX attribute read, which is the adapter-poll channel the observation
design already budgets — but the budget must assume that channel carries the majority of
actions on this class of app, not the minority.

## Findings that generalise

1. **`AXManualAccessibility` matters, but is not universal.** Obsidian's driver set sets it
   before the run (`axprobe --enable-ax`, now a `--enable-ax` passthrough on the runner).
   Without it a Chromium app reports near-silence — which would be recorded as a false
   Silent on all 20 actions, not a measurement. Note the flag made **no difference for
   Figma**, whose tree was already populated; treat it as a required precaution, not a
   reliable switch.
2. **"Keyboard shortcuts self-describe" partially survives into Electron.** Obsidian emitted
   31 `AXMenuItemSelected` events in run 1, carrying real command titles — `menu(Undo)`,
   `menu(Cut|Paste)`, `menu(Italics|Select All)`. Commands an Electron app mirrors into the
   **native** macOS menu bar do produce semantic command events for free. Commands handled
   purely inside the web app do not. That split is predictable per app and is worth
   auditing when a command set is specced.
3. **Some real actions are genuinely invisible.** *save note* was Silent in all three runs:
   Obsidian autosaves, so the explicit save command is close to a no-op and emits nothing.
   A tutor script for this app should not contain a "save" step; there is nothing to
   observe and nothing to verify.
4. **Instrument caveat, stated rather than buried.** *split pane* scored Silent, Silent,
   Usable. Its driver assumes `⌘\` is bound to Split Right; a direct check showed the
   keystroke changing nothing at all on two occasions. It is a **suspect driver**, not an
   established app property, and it should be re-authored against a verified hotkey before
   this action is counted either way. Excluding it entirely moves the median from 17/20 to
   17/19 — still UNDECIDED.
5. **Repeat runs are cheap and they change conclusions.** Three passes cost ~22 minutes and
   moved this from "15/20, fails the bar" to "UNDECIDED, needs more runs". The same protocol
   on TextEdit moved 20/20 → 17/20. Single runs at this bar are not evidence.

## What this implies for the architecture

Nothing here forces the hit-testing fallback to become primary — but nothing here clears
observer-primary either, for this class of app. The honest reading:

- On **AppKit** targets, the observer channel carries semantics directly and cheaply.
- On **browser-backed** targets, it carries *change detection*, and semantics come from
  attribute reads. That is still far cheaper than screenshots, but it is a different cost
  curve, and the look budget should be priced against the app class the wedge actually is.

The fallback is built regardless per delivery-plan §4.5, so no schedule changes on this
result.

## What remains

- More repetitions for Obsidian if a decision on this app is ever needed — the tooling
  supports `--repeat N` and the aggregator reports the bracket.
- Re-author the *split pane* driver against a verified hotkey.
- The **wedge-app run is still what decides Phase 0.** Figma is authored and queued behind
  a sign-in; Keynote is authored as the native-canvas control.
