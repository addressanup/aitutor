# Snapshot-ritual reliability — com.apple.TextEdit — "File>Save" — 2026-08-03 11:27

- Runs: 50   Failures: 0
- A run counts as a success only when the artifact landed on disk **and** focus returned.
- Total over 50 successful rituals: min 0.290s · p50 0.321s · p95 0.372s · max 0.394s

## Per-phase p50 / p95 (cumulative seconds from t0)

| Phase | p50 | p95 |
|---|---|---|
| resolve | 0.001 | 0.002 |
| press | 0.001 | 0.003 |
| panel | 0.168 | 0.202 |
| fill | 0.169 | 0.202 |
| confirm | 0.169 | 0.202 |
| file | 0.310 | 0.360 |
| focus | 0.321 | 0.372 |

- Budget: p95 must sit within the 2–4 s ritual window (delivery-plan Phase 0 bar: 50 consecutive, 0 failures, p95 in window, replicated on a second Mac).

Raw per-run logs and `phases.tsv` in this directory.
