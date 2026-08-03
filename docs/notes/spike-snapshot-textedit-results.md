# Snapshot-ritual spike — results: com.apple.TextEdit, "File > Export as PDF…" (headless protocol validation)

**Date:** 2026-08-03 · **Machine:** dev Mac (Darwin 25.5.0, Apple Silicon) · **Mode:** fully headless — `shell/Scripts/snapshot-ritual-run.sh` looping the app-generic `snapshot-spike` binary, sheet dismissed between runs by `axdrive`.
**Raw numbers:** `docs/notes/spike-snapshot-runs/textedit-headless-20260803-091351/` (50 per-run logs + timings).

## Result

| Metric | Value | Phase 0 bar |
|---|---|---|
| Consecutive invocations | 50 | 50 |
| Failures | **0** | 0 |
| p50 | 2.164 s | — |
| **p95** | **2.188 s** | within 2–4 s |
| min / max | 2.146 s / 2.649 s | — |

**Bar status on this machine: met** — 50/50, p95 comfortably inside the window, with remarkably tight dispersion (p95−p50 = 24 ms; the single 2.65 s outlier still lands mid-window).

## Scope — what this measured and what it didn't

- Measured: menu-path resolve → AX press → save-sheet appearance, per invocation, with the sheet dismissed (Esc) between runs. The spike binary's own timing instrumentation was used unmodified.
- **Not yet measured:** completing the export to a file (sheet → filename → confirm → file-exists assertion) and **focus restore** to the prior app — both are part of the real ritual and land when the loop is pointed at the wedge app's export flow (the full ritual is what carries the ≥99% M0 gate).
- **Replication on a second Mac is outstanding** — the Phase 0 bar requires it verbatim ("replicated on a second Mac before the review"). The harness is one command on any Mac with the repo cloned, the target app installed, and Accessibility granted to the terminal: `make spike-snapshot-run TARGET=<bundle-id> MENU="File>…" RUNS=50`.

## Read-through to the assessment contract

A ~2.2 s p95 for resolve→press→sheet on a lightweight AppKit app leaves roughly half the 2–4 s budget for the heavier half of the real ritual (export completion + focus restore) before the window is threatened. No evidence here forces an assessment-contract redesign; the wedge-app run decides it.
