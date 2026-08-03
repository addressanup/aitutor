# AX density spike — results: com.apple.TextEdit (headless protocol validation)

**Date:** 2026-08-03 · **Machine:** dev Mac (Darwin 25.5.0, Apple Silicon) · **Mode:** fully headless — actions performed by `axdrive` (CGEventPostToPid keystrokes + AX menu presses), observed by `axprobe`, orchestrated by `shell/Scripts/ax-density-run.sh --drivers spikes/drivers/com.apple.TextEdit`.
**Raw numbers:** run A `docs/notes/spike-ax-runs/textedit-headless-20260803-091351/` · run B `docs/notes/spike-ax-runs/textedit-headless-20260803-104345/`.

> **Revision (2026-08-03, same day).** The original version of this document reported
> **20/20 Usable** from a single run, with the verdict column filled in by eye. Verdicts
> are now computed by `shell/Scripts/ax-density-verdict.mjs` from the run's own logs, and
> a second run of the identical protocol scores **17/20**. The headline claim has been
> revised accordingly, and the reason the two disagree is itself the most useful finding
> here.

## What this run answers — and what it doesn't

This is the app-agnostic density protocol run end-to-end on a real app, with zero human
driving. TextEdit is a best-case AppKit citizen; the decision threshold (≥17/20 ⇒
observer-primary) is a per-target-app question, and the app where density is genuinely at
risk is a custom-canvas surface. **This run validates the instrument and the protocol; the
wedge-app verdict re-runs the same command against that app with its own driver set.**

## Method

30 s hands-off baseline, then one 20 s AXObserver window per action, the action performed
~3× by the scripted driver. Baseline: **0 events in 30 s** — an idle TextEdit emits
nothing, so anything in an action window is signal.

Verdicts are **computed, not judged**, against the bar's own wording — "fires every rep,
attributable above baseline, semantically distinct (directly or via one AX attribute
read)":

| Tier | Meaning |
|---|---|
| **Usable** | fires on every rep, above ambient, and its notification signature is unique across the 20 |
| **Usable\*** | fires on every rep, but shares a signature with another action and is separable only by reading an attribute — which the bar explicitly permits, so it counts |
| **Partial** | does not fire on every rep, or collides with nothing readable to separate it |
| **Silent** | indistinguishable from ambient |

"Fires every rep" is decided by clustering event timestamps into bursts (drivers sleep
300–500 ms between repetitions, so the silences are real boundaries) and requiring at
least as many bursts as the driver's declared `# reps:`. Rerun the tool on either
directory to reproduce the table.

## Result — run B: 17/20 (14/20 strictly distinct)

**Against the decision bar: 17/20 ≥ 17/20 ⇒ observer-primary for this target**, but only
just, and only when the attribute-read allowance is counted. The three failures:

| # | Action | Events | Bursts/Reps | Why not Usable |
|---|---|---|---|---|
| 6 | copy selection | 5 | 2/3 | `⌘C` emitted **no `AXMenuItemSelected` at all** this run — the signature carries only `menu(Select All)`. Run A recorded `Copy ×3`. |
| 11 | align center via menu | **2** | 2/3 | The menu-driven action produced 2 events. Run A recorded **67**. |
| 12 | font size bigger | 34 | 2/3 | Fired on two of three repetitions. Run A recorded 76 events. |

Three further actions clear the bar only via an attribute read: **cursor navigation**
(collides with the degenerate signature that failing align-center left behind), and
**new paragraph typing** ↔ **delete characters**, which are genuinely indistinguishable by
notification type — both are `AXSelectedTextChanged + AXValueChanged`. Typing and deleting
look identical to an observer until it reads the value.

## The finding that matters most

**The measurement is noisy, and a single eyeballed run is not evidence at the bar
boundary.** Same machine, same drivers, same protocol, ninety minutes apart:

| | Run A (eyeballed) | Run B (computed) |
|---|---|---|
| Score | 20/20 | 17/20 counted · 14/20 strict |
| align center | 67 events | 2 events |
| copy selection | 16 events, `Copy ×3` | 5 events, no `Copy` |
| bold toggle | 70 events | 184 events |

Run A's own logs cannot adjudicate this, because they predate per-event timestamps: the
verdict tool scores that directory **0/20**, not because TextEdit is silent — the events
are plainly there — but because the committed evidence cannot support the per-rep
criterion. That is the reproducibility gap the tool exists to close.

The practical consequence: **the ≥17/20 bar should be applied to a median of repeated
runs, not a single one**, and a target that lands within a point or two of 17 should be
treated as undecided rather than passing. A single run decided the architecture in the
original write-up; it should not.

## Findings that generalize beyond TextEdit

1. **Keyboard shortcuts self-describe — usually.** A keystroke with a menu equivalent
   normally emits `AXMenuItemSelected` carrying the command's title (`Select All`, `Paste`,
   `Cut`, `Save`), which is the semantic command event the session tape wants, for free.
   But run B's `⌘C` emitted none, so this is a strong tendency, not an invariant, and the
   observation layer needs a fallback for the misses.
2. **Synthetic input is observationally equivalent.** CGEventPostToPid-driven actions
   produce the same app-level notifications hardware input would, so headless density runs
   are valid measurements.
3. **Zero ambient noise** in TextEdit: attribution needed no statistical filtering. The
   harness records a baseline anyway, and the verdict tool subtracts it with Poisson slack,
   because noisier apps will need it.
4. **`AXPress` on menu items is unreliable as an actuator, not just as an emitter.** The
   known symptom was under-emitting `AXMenuItemSelected` (~1 per 3 presses versus 3 of 3
   for keyboard equivalents). Run B shows the stronger version: the menu-driven
   align-center action produced almost nothing, and separately — see the snapshot spike —
   `AXPress` on a *background* app's menu item resolves, reports success, and never
   invokes the command at all. Driver sets should prefer `key` over `menu` wherever a
   shortcut exists, and anything AX-driven must activate the target first.
5. **Notification type alone is not identity.** Typing and deleting share a signature.
   Any observer built on notification types must budget an attribute read to disambiguate,
   which is exactly the adapter-poll channel the observation design already assumes.

## What remains for the Phase 0 exit

- Re-run against the chosen wedge app with a founder-authored ~20-action driver set
  (`make spike-ax-run TARGET=<bundle-id> DRIVERS=<dir>`); apply the ≥17/20 bar there,
  **over repeated runs**. The custom-canvas surfaces are where the hit-testing fallback
  question actually gets decided.
- The fallback (AX hit-testing at observed clicks + keystroke-to-command mapping) is built
  regardless per the delivery plan (§4.5).
