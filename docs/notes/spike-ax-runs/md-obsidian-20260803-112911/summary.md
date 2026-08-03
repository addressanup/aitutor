# AX density run — md.obsidian — 2026-08-03 11:36

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
| 1 | type text | 28 | 1.40 | 2/3 | `AXSelectedTextChanged+AXTitleChanged+AXUIElementDestroyed+AXValueChanged` | **Partial** | 2 bursts for 3 reps |
| 2 | heading via hash | 500 | 25.00 | 5/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+menu(Select All)` | **Usable*** | fires every rep; separable from insert wiki link only by an attribute read |
| 3 | bold toggle | 42 | 2.10 | 5/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+menu(Bold|Select All)` | **Usable** | 5 bursts >= 3 reps, signature unique |
| 4 | italic toggle | 18 | 0.90 | 4/3 | `AXApplicationActivated+AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+menu(Italics|Select All)` | **Usable** | 4 bursts >= 3 reps, signature unique |
| 5 | insert wiki link | 59 | 2.95 | 2/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated+menu(Select All)` | **Partial** | 2 bursts for 3 reps |
| 6 | bullet list | 341 | 17.05 | 3/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from toggle reading view only by an attribute read |
| 7 | toggle checkbox | 120 | 6.00 | 1/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Partial** | 1 bursts for 3 reps |
| 8 | code fence | 272 | 13.60 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from toggle checkbox, select all, delete characters, redo only by an attribute read |
| 9 | select all | 57 | 2.85 | 6/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from toggle checkbox, code fence, delete characters, redo only by an attribute read |
| 10 | cut and paste word | 67 | 3.35 | 6/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXTitleChanged+AXValueChanged+menu(Cut|Paste)` | **Usable** | 6 bursts >= 3 reps, signature unique |
| 11 | delete characters | 59 | 2.95 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from toggle checkbox, code fence, select all, redo only by an attribute read |
| 12 | undo | 23 | 1.15 | 3/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXTitleChanged+AXValueChanged+menu(Undo)` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 13 | redo | 14 | 0.70 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from toggle checkbox, code fence, select all, delete characters only by an attribute read |
| 14 | find in note | 183 | 9.15 | 10/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from switch note only by an attribute read |
| 15 | global search | 101 | 5.05 | 6/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from command palette only by an attribute read |
| 16 | command palette | 93 | 4.65 | 9/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from global search only by an attribute read |
| 17 | switch note | 169 | 8.45 | 9/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from find in note only by an attribute read |
| 18 | toggle reading view | 24 | 1.20 | 3/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from bullet list only by an attribute read |
| 19 | split pane | 0 | 0.00 | 0/3 | `—` | **Silent** | 0 events vs ambient ceiling 0.0 |
| 20 | save note | 0 | 0.00 | 0/3 | `—` | **Silent** | 0 events vs ambient ceiling 0.0 |

**Mechanical score: 15/20 Usable** (4/20 distinct on notification types alone; 11 separable only by an AX attribute read). Bar: >=17/20 ⇒ observer-primary.

## Driver errors

None.
