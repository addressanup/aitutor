# drivers

Per-app action sets for the headless AX density protocol
(`shell/Scripts/ax-density-run.sh --drivers <dir>`). One directory per bundle id;
`NN-*.axd` files run in sorted order, each performing ONE canonical action ~3x via
the `axdrive` DSL. An optional `setup.sh` seeds app state (open a scratch doc); run
it before the harness. Findings go to `docs/notes/`, never here.

## Headers

    # name: bold toggle      names the action in the coverage table (defaults to the filename)
    # reps: 3                how many times the action is performed (defaults to 3)

`reps` is read by `shell/Scripts/ax-density-verdict.mjs`: an action is only **Usable**
if its events cluster into at least that many bursts, so a driver that repeats an
action four times must say so or it will be scored against three.

## Driver sets

Four targets, chosen so the density answer is not one app's answer. Each `setup.sh`
is run once, by hand, before the harness; all four refuse to run against real work.

| Bundle id | Toolkit | Setup requirement |
|---|---|---|
| `com.apple.TextEdit` | AppKit text | none — seeds and opens its own RTF scratch file |
| `com.figma.Desktop` | canvas, cloud | sign in, then open a **throwaway** design file and leave it frontmost |
| `md.obsidian` | Electron / Chromium | seeds a throwaway vault at `/tmp/aitutor-spike-vault`; open that vault (once) and a note in it |
| `com.apple.iWork.Keynote` | AppKit canvas | creates + saves `/tmp/aitutor-spike-keynote.key` via AppleScript — needs an Automation grant |

`md.obsidian` is the architecturally load-bearing one: it decides whether a
browser-backed app exposes AX a tutor can observe at all. Chromium builds its
accessibility tree lazily, so its `setup.sh` sets `AXManualAccessibility` on the
running process (`axprobe --enable-ax`) before the run — without it the probe
reports near-silence and every action scores a false Silent. Relaunching Obsidian
drops the flag; re-run `setup.sh`. `com.apple.iWork.Keynote` is the native-canvas
control for it: same 20-action shape, same mouse verbs, AppKit instead of a web view.

## DSL

| Command | Meaning |
|---|---|
| `activate` | bring the app frontmost and wait |
| `menu Format>Text>Center` | press a menu item along a title path |
| `key cmd+shift+z` | post a key chord |
| `type Hello world` | post text as unicode key events |
| `sleep 500` | pause N **milliseconds** |
| `press Save` / `press OKButton` | AX-press an element by title or identifier |
| `setvalue saveAsNameTextField draft` | set an element's AXValue by identifier |
| `moveto 50% 60%` | move the pointer |
| `click 50% 60%` / `doubleclick 50% 60%` | click at a point |
| `drag 20% 30% 60% 70%` | press, drag along a path, release |

Blank lines are ignored and `#` starts a comment anywhere on a line, so a literal
`#` cannot appear in `type` text.

**Coordinates** are relative to the focused window and accept either points from its
top-left (`click 300 220`) or fractions of its size (`click 50% 60%`). Prefer
fractions: they are what survives a different display when the run is replicated on
another machine.

## Things learned the hard way

- **Prefer `key` over `menu` where a shortcut exists.** Menu items pressed via
  `AXPress` under-emit `AXMenuItemSelected` (~1 per 3 presses) versus keyboard
  equivalents (3 of 3). Learners drive by keyboard, so the reliable path is also the
  representative one.
- **`AXPress` on a background app's menu item does nothing at all** — it resolves and
  reports success without invoking the command. Always `activate` first.
- **Input posted to the target pid never reaches an out-of-process panel** (save/open
  sheets are rendered by `com.apple.appkit.xpc.openAndSavePanelService`). `key esc`
  cannot dismiss one; `press CancelButton` can, because AX does reach it. Use
  `--global-input` only when a panel is confirmed present — if it is not, typed text
  lands in the learner's document.
- **Canvas apps need the mouse verbs.** A keyboard-only driver set systematically
  under-samples exactly the surface the density question is about.
- **Discover, don't guess.** `axprobe --dump-menu` prints the real menu title tree and
  `axprobe --dump-tree` prints the focused window's roles, identifiers, values and
  available actions. Author driver sets from those, not from memory of the UI.
