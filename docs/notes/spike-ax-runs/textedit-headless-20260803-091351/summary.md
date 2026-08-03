# AX density run — com.apple.TextEdit — 2026-08-03 09:21

Mode: headless (axdrive).
Window: 20s/action. Baseline: 30s hands-off.

## Baseline (ambient noise)

```
— notification counts —

  total: 0   rate: 0.00 events/sec
```

## Per-action draft table

Verdict scale: **Usable** (fires every rep, attributable, semantically distinct) / **Partial** (unreliable or ambiguous) / **Silent**.

| # | Action | Events | Rate (ev/s) | Top notifications | Verdict |
|---|--------|--------|-------------|-------------------|---------|
| 1 | type text | 241 | 12.05 | AXSelectedTextChanged×120; AXValueChanged×120; AXApplicationActivated×1;  | |
| 2 | select all | 22 | 1.10 | AXFocusedUIElementChanged×6; AXSelectedTextChanged×6; AXMenuItemSelected×3; AXUIElementDestroyed×3; AXWindowCreated×3; AXWindowMoved×1;  | |
| 3 | bold toggle | 70 | 3.50 | AXValueChanged×54; AXFocusedUIElementChanged×8; AXMenuItemSelected×4; AXSelectedTextChanged×2; AXWindowCreated×1; AXUIElementDestroyed×1;  | |
| 4 | italic toggle | 70 | 3.50 | AXValueChanged×54; AXFocusedUIElementChanged×8; AXMenuItemSelected×4; AXSelectedTextChanged×2; AXWindowCreated×1; AXUIElementDestroyed×1;  | |
| 5 | underline toggle | 73 | 3.65 | AXValueChanged×57; AXFocusedUIElementChanged×8; AXMenuItemSelected×4; AXSelectedTextChanged×2; AXWindowCreated×1; AXUIElementDestroyed×1;  | |
| 6 | copy selection | 16 | 0.80 | AXFocusedUIElementChanged×8; AXMenuItemSelected×4; AXSelectedTextChanged×2; AXWindowCreated×1; AXUIElementDestroyed×1;  | |
| 7 | paste | 16 | 0.80 | AXFocusedUIElementChanged×6; AXSelectedTextChanged×4; AXMenuItemSelected×3; AXValueChanged×3;  | |
| 8 | cut and restore word | 33 | 1.65 | AXFocusedUIElementChanged×12; AXSelectedTextChanged×9; AXValueChanged×6; AXMenuItemSelected×6;  | |
| 9 | undo | 18 | 0.90 | AXSelectedTextChanged×6; AXFocusedUIElementChanged×6; AXValueChanged×3; AXMenuItemSelected×3;  | |
| 10 | redo | 18 | 0.90 | AXSelectedTextChanged×6; AXFocusedUIElementChanged×6; AXValueChanged×3; AXMenuItemSelected×3;  | |
| 11 | align center via menu | 67 | 3.35 | AXValueChanged×57; AXWindowMoved×3; AXSelectedTextChanged×2; AXFocusedUIElementChanged×2; AXMenuItemSelected×1; AXUIElementDestroyed×1; AXWindowCreated×1 | |
| 12 | font size bigger | 76 | 3.80 | AXValueChanged×57; AXFocusedUIElementChanged×8; AXMenuItemSelected×4; AXWindowMoved×3; AXSelectedTextChanged×2; AXWindowCreated×1; AXUIElementDestroyed×1 | |
| 13 | font size smaller | 78 | 3.90 | AXValueChanged×57; AXFocusedUIElementChanged×8; AXMenuItemSelected×4; AXWindowMoved×3; AXApplicationActivated×2; AXSelectedTextChanged×2; AXUIElementDestr | |
| 14 | find bar open search close | 51 | 2.55 | AXValueChanged×16; AXFocusedUIElementChanged×14; AXSelectedTextChanged×13; AXUIElementDestroyed×5; AXMenuItemSelected×2; AXApplicationActivated×1;  | |
| 15 | cursor navigation | 10 | 0.50 | AXSelectedTextChanged×10;  | |
| 16 | new paragraph typing | 119 | 5.95 | AXSelectedTextChanged×60; AXValueChanged×59;  | |
| 17 | delete characters | 12 | 0.60 | AXValueChanged×6; AXSelectedTextChanged×6;  | |
| 18 | menu open close | 18 | 0.90 | AXFocusedUIElementChanged×15; AXMenuOpened×3;  | |
| 19 | ruler toggle | 12 | 0.60 | AXFocusedUIElementChanged×8; AXMenuItemSelected×4;  | |
| 20 | save document | 9 | 0.45 | AXFocusedUIElementChanged×6; AXMenuItemSelected×3;  | |
