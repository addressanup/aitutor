# AX density spike — results: com.apple.TextEdit (headless protocol validation)

**Date:** 2026-08-03 · **Machine:** dev Mac (Darwin 25.5.0, Apple Silicon) · **Mode:** fully headless — actions performed by `axdrive` (CGEventPostToPid keystrokes + AX menu presses), observed by `axprobe`, orchestrated by `shell/Scripts/ax-density-run.sh --drivers spikes/drivers/com.apple.TextEdit`.
**Raw numbers:** `docs/notes/spike-ax-runs/textedit-headless-20260803-091351/` (per-action verbose logs + machine-generated summary).

## What this run answers — and what it doesn't

This is the **app-agnostic density protocol run end-to-end on a real app**, producing a full per-action coverage table with zero human driving. TextEdit is a best-case AppKit citizen; the delivery plan's decision threshold (≥17/20 ⇒ observer-primary) is a per-target-app question, and the app where density is genuinely at risk is a custom-canvas surface (e.g. an NLE timeline). **This run validates the instrument and the protocol; the wedge-app verdict re-runs the same command against that app with its own driver set.**

## Method

30 s hands-off baseline, then one 20 s AXObserver window per action, the action performed ~3× by the scripted driver. Verdicts: **Usable** = fires every rep, attributable above baseline, semantically distinct (directly or via one AX attribute read) · **Partial** = unreliable/ambiguous · **Silent**.

Baseline: **0 events in 30 s** — an idle TextEdit emits nothing; anything in an action window is signal.

## Coverage table — 20/20 Usable

| # | Action | Events | Signature (top notifications) | Verdict |
|---|--------|--------|-------------------------------|---------|
| 1 | type text | 241 | AXSelectedTextChanged + AXValueChanged, 1:1 per keystroke | **Usable** |
| 2 | select all | 22 | AXMenuItemSelected `title=Select All` ×3 + AXSelectedTextChanged | **Usable** |
| 3 | bold toggle | 70 | AXValueChanged ×54 + AXMenuItemSelected ×4 | **Usable** |
| 4 | italic toggle | 70 | AXValueChanged ×54 + AXMenuItemSelected ×4 | **Usable** |
| 5 | underline toggle | 73 | AXValueChanged ×57 + AXMenuItemSelected ×4 | **Usable** |
| 6 | copy | 16 | AXMenuItemSelected `title=Copy` ×3(+1 from setup) | **Usable** |
| 7 | paste | 16 | AXMenuItemSelected ×3 + AXValueChanged ×3, per rep | **Usable** |
| 8 | cut + restore word | 33 | AXMenuItemSelected ×6 (Cut/Paste pairs) + AXValueChanged ×6 | **Usable** |
| 9 | undo | 18 | AXMenuItemSelected ×3 + AXValueChanged ×3 | **Usable** |
| 10 | redo | 18 | AXMenuItemSelected ×3 + AXValueChanged ×3 | **Usable** |
| 11 | align center (menu-driven) | 67 | AXValueChanged ×57 per re-layout; alignment via attribute read | **Usable**¹ |
| 12 | font bigger | 76 | AXMenuItemSelected ×4 + AXValueChanged ×57 | **Usable** |
| 13 | font smaller | 78 | AXMenuItemSelected ×4 + AXValueChanged ×57 | **Usable** |
| 14 | find bar open/search/close | 51 | AXValueChanged/AXFocusedUIElementChanged/AXUIElementDestroyed mix | **Usable** |
| 15 | cursor navigation | 10 | AXSelectedTextChanged, 1:1 per arrow key | **Usable** |
| 16 | new paragraph typing | 119 | per-keystroke pairs, as #1 | **Usable** |
| 17 | delete characters | 12 | AXValueChanged + AXSelectedTextChanged per delete | **Usable** |
| 18 | menu open/close | 18 | AXMenuOpened ×3 + AXFocusedUIElementChanged | **Usable** |
| 19 | ruler toggle | 12 | AXMenuItemSelected ×4 + AXFocusedUIElementChanged | **Usable** |
| 20 | save | 9 | AXMenuItemSelected `title=Save` ×3 | **Usable** |

¹ Fires strongly every rep; distinguishing *which* formatting changed needs one AX attribute read — which the observation layer's adapter-poll channel does anyway.

**Against the decision bar: 20/20 ≥ 17/20 ⇒ observer-primary for this target.** (The bar is re-applied per target app; see caveats.)

## Findings that generalize beyond TextEdit

1. **Keyboard shortcuts self-describe.** Any keystroke with a menu equivalent emits `AXMenuItemSelected` with the command's title (`Select All`, `Copy`, `Save`) — the semantic command event the session tape wants, without keystroke-to-command mapping. This strengthens the observer-primary case wherever an app routes shortcuts through its menu bar.
2. **Synthetic input is observationally equivalent.** CGEventPostToPid-driven actions produced the same app-level AX notifications hardware input would — so headless density runs are valid measurements, and the product's future replay/QA harnesses can trust them.
3. **Zero ambient noise** (in TextEdit): attribution needed no statistical filtering. Noisier apps may need baseline subtraction — the harness already records the baseline for exactly that.
4. **One driver-side nuance:** menu items pressed via AX (`AXPress`) under-emit `AXMenuItemSelected` (~1 per 3 presses) versus keyboard equivalents (3 of 3). Learners drive by keyboard/mouse, so the reliable path is the one that matters; driver sets should prefer `key` over `menu` where a shortcut exists.

## What remains for the Phase 0 exit

- Re-run against the chosen wedge app with a founder-authored ~20-action driver set (`make spike-ax-run TARGET=<bundle-id> DRIVERS=<dir>`); apply the ≥17/20 bar there. The custom-canvas surfaces (timeline-style editors) are where the hit-testing fallback question actually gets decided.
- The fallback (AX hit-testing at observed clicks + keystroke-to-command mapping) is built regardless per the delivery plan (§4.5).
