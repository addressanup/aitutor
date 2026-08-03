# Replicating the Phase 0 spikes on a second Mac

**Audience:** an operator with a second Mac and no context on this repo.
**Why this exists:** the Phase 0 snapshot bar is "50 consecutive scripted invocations,
0 failures, p95 within the 2–4 s window, **replicated on a second Mac** before the
review" (delivery-plan §5 Phase 0). One machine cannot satisfy that sentence, and a
result that only reproduces on the machine that produced it is not a measurement.

Read the two honesty notes first — they say what these numbers do and do not mean:
`docs/notes/spike-ax-textedit-results.md` and `docs/notes/spike-snapshot-textedit-results.md`.

---

## What is worth replicating today — and what is not

| Protocol | Replicable now? | Why |
|---|---|---|
| **AX density** (`make spike-ax-run`) | **Yes — this is the useful one.** | The instrument works end-to-end and scores itself. Cross-machine variance is exactly the open question: the same drivers, same app, same day scored 20/20 and 17/20 ninety minutes apart on one machine. A second Mac's numbers are new evidence. |
| **Snapshot ritual** (`make spike-snapshot-run`) | **No — blocked, not pending.** | The bar is **not met** on the reference machine. The ritual stops at `confirm`: an `NSSavePanel` cannot be driven to completion through Accessibility alone, so no artifact reaches disk and no run counts as a success. Replicating a run that fails on machine one only proves it fails on machine two. |

The snapshot protocol unblocks when either (a) a target whose save panel is in-process
is chosen, or (b) the decision is taken to drive panels with tagged global HID input.
Until then, running it on a second Mac is welcome as a *diagnostic* — it confirms the
failure phase is the same one — but it cannot close the Phase 0 bar. Say which you are
doing when you report back.

Both protocols are app-agnostic: the target is always a bundle id passed at runtime.
Nothing here is specific to TextEdit — TextEdit is a best-case AppKit citizen used to
validate the instrument, not the app the architecture decision is about.

---

## 1. Clone

```sh
git clone <repo-url> aitutor
cd aitutor
```

Record the commit you are on (`git rev-parse --short HEAD`) — it goes in the report.

## 2. Toolchain

| Need | Floor | Get it |
|---|---|---|
| Xcode + Swift | Swift **6.2** (`shell/Package.swift` tools version) | App Store, launch once, then `sudo xcode-select -s /Applications/Xcode.app`. Command Line Tools alone can ship an older Swift. |
| Node | **26** (`package.json` engines) | nodejs.org or `brew install node`. The density verdicts are computed by a Node script. |
| pnpm | 10.x | `corepack enable` |

```sh
make bootstrap        # pnpm install + core/.env
make check            # should be green before you measure anything
```

## 3. Preflight

```sh
make spike-doctor TARGET=<bundle-id>
```

It checks the repo layout, the toolchain floors, that the three spike binaries build,
that **this terminal** holds Accessibility, and that the target app is installed and
running. Every ✗ carries its own fix. It exits non-zero until the machine is ready;
do not run a protocol against a machine it is still failing.

## 4. Grant Accessibility — to your terminal

This is the step that trips everyone, and it is not intuitive.

**A CLI tool has no TCC identity of its own; it inherits the identity of the terminal
app hosting it.** `axprobe`, `axdrive`, and `snapshot-spike` are unsigned debug
binaries run from a shell, so the Accessibility grant they use belongs to Terminal, or
iTerm, or VS Code, or Ghostty — whichever one you typed the command into.

1. **System Settings → Privacy & Security → Accessibility**
2. Click **+**, add your terminal app (e.g. `/System/Applications/Utilities/Terminal.app`)
3. Switch its toggle **ON**
4. **Quit and reopen the terminal** — the grant is read at process start, so an
   already-running terminal keeps its old answer.

**The grant is per terminal app.** Switching from Terminal to iTerm mid-session means
granting iTerm as well; the symptom is a protocol that worked an hour ago suddenly
reporting "Accessibility not granted". `make spike-doctor` names the terminal it
detected, so you can check you granted the right one.

Unrelated to this: `make cert` / `make reset-tcc` are about the bundled `Tutor.app`,
which is a different TCC identity again. Ignore them for replication.

## 5. Run the density protocol

```sh
bash spikes/drivers/<bundle-id>/setup.sh          # if the driver set ships one
make spike-ax-run TARGET=<bundle-id> DRIVERS=spikes/drivers/<bundle-id>
```

30 s hands-off baseline, then one 20 s observation window per action while `axdrive`
performs it. **Leave the machine alone for the whole run** — it drives the keyboard and
mouse of the target app, and touching either contaminates the window. Budget ~10 min
for a 20-action set.

Then run it **at least three times**. A single run is not evidence at the bar boundary;
that finding is the main result of the reference machine's own runs.

## 6. Run the snapshot protocol (diagnostic only, see above)

```sh
make spike-snapshot-run TARGET=<bundle-id> MENU="File>Export as PDF…" RUNS=50
```

## 7. Where results land

| Path | What |
|---|---|
| `docs/notes/spike-ax-runs/<id>-<timestamp>/` | per-action logs, `00-baseline.log`, `summary.md` with the computed verdict table |
| `docs/notes/spike-snapshot-runs/<id>-<timestamp>/` | per-run logs, `times.txt`, `phases.tsv`, `summary.md` |

Verdicts are recomputed from the logs, never typed in — rerun
`node shell/Scripts/ax-density-verdict.mjs <run-dir> --drivers <driver-dir>` on any run
directory and you should get its table back byte-for-byte. If you cannot, the run
directory is not evidence.

## 8. What to send back

Send the whole run directories, not a summary of them — the point of replication is
that someone else can recompute your conclusion.

1. **Machine facts:** macOS version (`sw_vers`), chip, display resolution and scaling,
   target app version, `git rev-parse --short HEAD`.
2. **`make spike-doctor` output**, verbatim, from the machine that ran the protocol.
3. **Every run directory** under `docs/notes/spike-ax-runs/` and, if you ran it,
   `docs/notes/spike-snapshot-runs/`.
4. **The scores of each density run**, listed separately — not averaged, not the best
   one. Disagreement between runs is the signal.
5. **Anything you touched during a run**, including the machine sleeping, a
   notification landing, or a driver you edited.

Do not edit the two results docs in `docs/notes/`. A second machine's numbers are a
new input to them, and reconciling two machines is a decision, not a merge.
