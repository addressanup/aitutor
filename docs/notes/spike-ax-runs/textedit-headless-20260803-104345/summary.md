# AX density run — com.apple.TextEdit — 2026-08-03 10:51

Mode: headless (axdrive).
Window: 20s/action. Baseline: 30s hands-off.

## Baseline (ambient noise)

```
— notification counts —

  total: 0   rate: 0.00 events/sec
```

## Per-action table

Verdict scale: **Usable** (fires every rep, attributable above ambient, semantically distinct) / **Partial** (unreliable or ambiguous) / **Silent**.
Verdicts are computed by `shell/Scripts/ax-density-verdict.mjs` from these logs — rerun it on this directory to reproduce them.

| # | Action | Events | Rate (ev/s) | Bursts/Reps | Signature | Verdict | Why |
|---|--------|--------|-------------|-------------|-----------|---------|-----|
| 1 | type text | 241 | 12.05 | 4/3 | `AXApplicationActivated+AXSelectedTextChanged+AXValueChanged` | **Usable** | 4 bursts >= 3 reps, signature unique |
| 2 | select all | 23 | 1.15 | 7/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+AXWindowMoved+menu(Select All)` | **Usable** | 7 bursts >= 3 reps, signature unique |
| 3 | bold toggle | 184 | 9.20 | 5/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+menu(Bold|Select All)` | **Usable** | 5 bursts >= 3 reps, signature unique |
| 4 | italic toggle | 66 | 3.30 | 5/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXValueChanged+menu(Italic|Select All)` | **Usable** | 5 bursts >= 3 reps, signature unique |
| 5 | underline toggle | 69 | 3.45 | 5/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXValueChanged+menu(Select All|Underline)` | **Usable** | 5 bursts >= 3 reps, signature unique |
| 6 | copy selection | 5 | 0.25 | 2/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+menu(Select All)` | **Partial** | 2 bursts for 3 reps |
| 7 | paste | 34 | 1.70 | 3/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXValueChanged+menu(Paste)` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 8 | cut and restore word | 33 | 1.65 | 6/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXValueChanged+menu(Cut|Paste)` | **Usable** | 6 bursts >= 3 reps, signature unique |
| 9 | undo | 18 | 0.90 | 3/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXValueChanged+menu(Undo Cut|Undo Paste)` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 10 | redo | 18 | 0.90 | 3/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXValueChanged+menu(Redo|Redo Cut|Redo Paste)` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 11 | align center via menu | 2 | 0.10 | 2/3 | `AXApplicationActivated+AXSelectedTextChanged` | **Partial** | 2 bursts for 3 reps |
| 12 | font size bigger | 34 | 1.70 | 2/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+menu(Bigger|Select All)` | **Partial** | 2 bursts for 3 reps |
| 13 | font size smaller | 35 | 1.75 | 3/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+menu(Select All|Smaller)` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 14 | find bar open search close | 25 | 1.25 | 5/2 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+menu(Find…)` | **Usable** | 5 bursts >= 2 reps, signature unique |
| 15 | cursor navigation | 11 | 0.55 | 4/3 | `AXApplicationActivated+AXSelectedTextChanged` | **Partial** | signature collides with align center via menu |
| 16 | new paragraph typing | 119 | 5.95 | 2/2 | `AXSelectedTextChanged+AXValueChanged` | **Partial** | signature collides with delete characters |
| 17 | delete characters | 12 | 0.60 | 3/3 | `AXSelectedTextChanged+AXValueChanged` | **Partial** | signature collides with new paragraph typing |
| 18 | menu open close | 18 | 0.90 | 6/3 | `AXFocusedUIElementChanged+AXMenuOpened` | **Usable** | 6 bursts >= 3 reps, signature unique |
| 19 | ruler toggle | 26 | 1.30 | 6/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+menu(Show Ruler)` | **Usable** | 6 bursts >= 3 reps, signature unique |
| 20 | save document | 68 | 3.40 | 5/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+menu(Save)` | **Usable** | 5 bursts >= 3 reps, signature unique |

**Mechanical score: 14/20 Usable** (bar: >=17/20 ⇒ observer-primary).

## Driver errors

None.
