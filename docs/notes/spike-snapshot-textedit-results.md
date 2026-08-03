# Snapshot-ritual spike — results: com.apple.TextEdit (`File > Save` and `File > Export as PDF…`)

**Date:** 2026-08-03 · **Machine:** dev Mac (Darwin 25.5.0, Apple Silicon) · **Mode:** fully headless — `shell/Scripts/snapshot-ritual-run.sh` looping the app-generic `snapshot-spike` binary.
**Raw numbers:** `docs/notes/spike-snapshot-runs/textedit-headless-20260803-091351/` (the superseded run) and `docs/notes/spike-snapshot-runs/textedit-save-20260803-112556/` (the completed 50-run ritual).

> **Correction (2026-08-03, same day).** An earlier version of this document reported
> "50/50, 0 failures, p95 2.188 s — **bar status on this machine: met**". **That
> conclusion was wrong and is withdrawn.** The measurement did not measure the ritual.
> The numbers themselves were real; what they measured was not what the document said.
> Details below, kept in full because the failure mode is instructive and cheap to
> repeat.
>
> **Update, same day.** The repaired harness has since completed **50/50 rituals with 0
> failures at p95 0.372 s** against `File > Save` — every run writing a file and restoring
> focus. That is the instrument's acceptance test, not the wedge verdict: a panel-less save
> skips the save-panel phases, which remain unreached. Both results are below.

## What the superseded run actually measured

`SnapshotSpike` polled for a save sheet 20 × 100 ms and then gave up. Across all 50
committed runs:

- **50/50 logs read `save sheet appeared: no`** — the sheet was never detected once.
- Menu resolve + press completed in **0.016–0.033 s**.
- Every total landed in **2.146–2.191 s** (one 2.649 s outlier), i.e.
  `press + 2.00 s poll ceiling + ~6 ms × 20 AX reads`.

So the reported **p95 of 2.188 s was the poll timeout constant**, not a latency. It
would reproduce at ~2.15 s on any Mac, because it was timing a two-second sleep. The
loop's success test required only `success: yes` from the *press* line plus a
parseable total, so "50 consecutive, 0 failures" meant **50 menu presses dispatched**,
not 50 rituals completed. The tight dispersion the old document praised
(p95 − p50 = 24 ms) was the giveaway: that is the signature of a constant, not of a
UI operation.

## Root causes, each confirmed by direct observation

1. **The sheet was there the whole time; the probe looked one level too deep.**
   When a sheet is up, `kAXFocusedWindowAttribute` returns **the sheet itself**. The
   probe asked whether the focused window *had a child* of role `AXSheet`, which can
   never match. With the predicate corrected, the panel is detected in **0.26–0.48 s**.
   The out-of-process `com.apple.appkit.xpc.openAndSavePanelService` does spawn, but
   AppKit bridges the panel's tree back into the app, so it was reachable all along.

2. **`AXPress` on a background app's menu item silently does nothing.** It resolves,
   returns success, and never invokes the command. The old spike never activated the
   target. `snapshot-spike` now activates first, and refuses to run if it cannot.

3. **The between-run reset never reset anything.** The loop dismissed state with
   `activate; key esc`, but keystrokes posted to the target pid never reach an
   out-of-process panel. One sheet opened on the first run and stood for all 50; every
   later "press" was dispatched into an app that already had a modal sheet up.

## The finding that matters to the product

**An `NSSavePanel` cannot be driven to completion through Accessibility alone.**
Every mechanism was tried against a real panel and observed directly:

| Mechanism | Result |
|---|---|
| Read the panel's tree (roles, ids, values) | **Works** — `AXSheet id=save-panel`, `AXTextField id=saveAsNameTextField`, `AXButton id=OKButton` |
| `AXPress` the Cancel button | **Works** — panel dismisses cleanly, focus returns |
| `setValue` the filename field | **Displays**, but does **not** bind to the panel's model — a later replace-confirmation named the *default* filename, not the one set |
| `AXConfirm` the filename field with an absolute path | Rejected — slashes are not a valid file name, and AX-set text does not trigger the path-resolution the keystroke path has |
| `AXPress` the Save button | Panel dismisses, **no file written** |
| Click Save at its own AX frame, global HID tap | Panel dismisses, **no file written** |
| Global Return (default-button activation) | Engages the save path — surfaced a **replace-confirmation sheet**, proving the mechanism reaches the panel |
| `key esc` / any input posted to the target pid | **Never arrives** — the panel is a different process |

The consequence for the executor: **completing an export ritual requires synthetic
input on the global HID tap**, not only `CGEventPostToPid`. That interacts directly
with the possession design — such events must carry the synthetic tag and pass the
possession gate, and the whitelist check cannot be a per-pid frontmost test alone,
because the process receiving the input is an AppKit XPC service the learner never
chose. This belongs in the Task 5/6 design, not only in spike code.

A second-order hazard, found the hard way: driving panels with global keystrokes is
**unsafe under failure**. When a panel failed to appear, typed text landed in the
learner's open document instead. Any production path that falls back to global typing
needs a panel-present precondition checked immediately before each post, and should
prefer a click at a known element frame over typing.

## Status against the Phase 0 bar

**Met for a panel-less export; not met for a save-panel export.** The bar is "50
consecutive scripted invocations, 0 failures, p95 within the 2–4 s window, replicated on a
second Mac". The repaired harness measures resolve → press → panel → fill → confirm →
**file on disk** → **focus restored**, with per-phase p50/p95, and a run counts only if the
artifact landed and focus returned.

### 50/50 on `File > Save` — the first completed ritual measurement

Raw: `docs/notes/spike-snapshot-runs/textedit-save-20260803-112556/` (50 logs + `phases.tsv`).

| Metric | Value | Bar |
|---|---|---|
| Consecutive invocations | 50 | 50 |
| Failures | **0** | 0 |
| p50 / **p95** | 0.321 s / **0.372 s** | p95 ≤ 4 s |
| min / max | 0.290 s / 0.394 s | — |

| Phase (cumulative) | p50 | p95 |
|---|---|---|
| menu resolve | 0.001 | 0.002 |
| press | 0.001 | 0.003 |
| panel (none raised) | 0.168 | 0.202 |
| confirm (nothing to confirm) | 0.169 | 0.202 |
| **artifact on disk** | 0.310 | 0.360 |
| **focus restored** | 0.321 | 0.372 |

Every one of those 50 runs wrote a file whose mtime falls inside the run and returned
focus to the app. **This is the instrument's own acceptance test, and it passes.** It is
also an order of magnitude inside the budget, which says the harness overhead is not what
will threaten the 2–4 s window.

**Scope, stated plainly:** `File > Save` over an already-located document is a far lighter
ritual than Export XML. It exercises resolve → press → artifact → focus, but **not** the
save-panel phases. It validates the instrument; it does not clear the wedge app's bar, and
the second-Mac replication remains outstanding.

### Save-panel exports remain unreached

Per Phase 0's instruction that a miss "produces a written gap analysis feeding the ≥99% M0
gate plan", the mechanism table above is that analysis. On `File > Export as PDF…` the
ritual reaches `confirm` and stops: the panel is found in 0.26–0.48 s, read, and dismissed,
but no mechanism tried writes a file.

The measured front half costs well under 0.5 s, leaving most of the window for the write
and focus restore. Nothing here forces an assessment-contract redesign. It does mean **the
completion channel for panel-based exports is an open design question**, and the wedge-app
run is what closes it.

## Outstanding

- **Second-Mac replication remains outstanding**, and is now correctly *blocked* rather
  than merely pending: replicating the superseded loop would have reproduced a timeout
  constant. The delivery plan already schedules two Mac minis in September; that is the
  intended replication fleet.
- The completed ritual needs a target whose save panel is in-process, or a decision to
  drive panels with tagged global input. Figma is unsandboxed and is the next target.
- Re-run command, unchanged in shape:
  `make spike-snapshot-run TARGET=<bundle-id> MENU="File>…" RUNS=50`
