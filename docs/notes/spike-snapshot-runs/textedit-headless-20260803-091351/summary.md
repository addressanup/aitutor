# Snapshot-ritual reliability — com.apple.TextEdit — "File>Export as PDF…" — 2026-08-03 09:24

- Runs: 50   Failures: 0
- Timing over 50 successful runs: min 2.146s · p50 2.164s · p95 2.188s · max 2.649s
- Budget: p95 must sit within the 2–4 s ritual window (delivery-plan Phase 0 bar: 50 consecutive, 0 failures, p95 in window, replicated on a second Mac).

Raw per-run logs in this directory. Note: this loop measures menu-resolve → press → sheet-appearance
and dismisses the sheet between runs; completing the export to a file is exercised when pointed at
the real target app's export flow.
