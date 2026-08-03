# AX density run — md.obsidian — 2026-08-03 11:46

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
| 1 | type text | 833 | 41.65 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from heading via hash, bold toggle, italic toggle, insert wiki link, bullet list, toggle checkbox, code fence, select all, delete characters, redo only by an attribute read |
| 2 | heading via hash | 523 | 26.15 | 5/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, bold toggle, italic toggle, insert wiki link, bullet list, toggle checkbox, code fence, select all, delete characters, redo only by an attribute read |
| 3 | bold toggle | 58 | 2.90 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, italic toggle, insert wiki link, bullet list, toggle checkbox, code fence, select all, delete characters, redo only by an attribute read |
| 4 | italic toggle | 52 | 2.60 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, insert wiki link, bullet list, toggle checkbox, code fence, select all, delete characters, redo only by an attribute read |
| 5 | insert wiki link | 162 | 8.10 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, italic toggle, bullet list, toggle checkbox, code fence, select all, delete characters, redo only by an attribute read |
| 6 | bullet list | 510 | 25.50 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, italic toggle, insert wiki link, toggle checkbox, code fence, select all, delete characters, redo only by an attribute read |
| 7 | toggle checkbox | 178 | 8.90 | 1/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Partial** | 1 bursts for 3 reps |
| 8 | code fence | 386 | 19.30 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, italic toggle, insert wiki link, bullet list, toggle checkbox, select all, delete characters, redo only by an attribute read |
| 9 | select all | 54 | 2.70 | 6/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, italic toggle, insert wiki link, bullet list, toggle checkbox, code fence, delete characters, redo only by an attribute read |
| 10 | cut and paste word | 78 | 3.90 | 6/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXTitleChanged+AXValueChanged+menu(Cut|Paste)` | **Usable** | 6 bursts >= 3 reps, signature unique |
| 11 | delete characters | 79 | 3.95 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, italic toggle, insert wiki link, bullet list, toggle checkbox, code fence, select all, redo only by an attribute read |
| 12 | undo | 31 | 1.55 | 3/3 | `AXFocusedUIElementChanged+AXMenuItemSelected+AXSelectedTextChanged+AXTitleChanged+AXValueChanged+menu(Undo)` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 13 | redo | 22 | 1.10 | 3/3 | `AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable*** | fires every rep; separable from type text, heading via hash, bold toggle, italic toggle, insert wiki link, bullet list, toggle checkbox, code fence, select all, delete characters only by an attribute read |
| 14 | find in note | 218 | 10.90 | 9/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from switch note only by an attribute read |
| 15 | global search | 89 | 4.45 | 7/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from command palette only by an attribute read |
| 16 | command palette | 113 | 5.65 | 9/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from global search only by an attribute read |
| 17 | switch note | 188 | 9.40 | 9/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXUIElementDestroyed+AXValueChanged+AXWindowCreated` | **Usable*** | fires every rep; separable from find in note only by an attribute read |
| 18 | toggle reading view | 24 | 1.20 | 3/3 | `AXFocusedUIElementChanged+AXSelectedTextChanged+AXTitleChanged+AXValueChanged` | **Usable** | 3 bursts >= 3 reps, signature unique |
| 19 | split pane | 0 | 0.00 | 0/3 | `—` | **Silent** | 0 events vs ambient ceiling 0.0 |
| 20 | save note | 0 | 0.00 | 0/3 | `—` | **Silent** | 0 events vs ambient ceiling 0.0 |

**Mechanical score: 17/20 Usable** (3/20 distinct on notification types alone; 14 separable only by an AX attribute read). Bar: >=17/20 ⇒ observer-primary.

## Driver errors

None.
