# aitutor — the Live AI Tutor

An AI tutor that lives on the learner's own computer and uses computer-use capability to **teach** — explain on a board, demonstrate live in real software, watch the learner practice, adapt — never to do the work for them. The concept brief is the product's constitution; the execution plan proposes the machine.

**Domain-open by construction:** nothing in `shell/`, `core/`, or `protocol/` is specific to any application. App targeting is always a runtime parameter (bundle ids, menu paths, per-app registries as data). Final Cut Pro appears in the docs as the first market wedge and as an example — never in code.

## Layout

| Path | What |
|---|---|
| `docs/execution-plan.md` | Execution Plan v1 (adversarially reviewed) — the why behind every decision here |
| `docs/notes/` | Constitution, research memos, design memos, review findings |
| `protocol/` | `@aitutor/protocol` — the normative IPC contract (zod schemas + golden fixtures) |
| `core/` | `@aitutor/core` — TypeScript agent-core: teaching-loop state machine, IPC client, journal, lesson schema |
| `shell/` | Swift shell — menu-bar app owning the OS organs: overlay, AX bridge, event-tap guard, permissions, IPC server |

Two processes on the learner's machine: the **shell** (WebSocket server on 127.0.0.1) owns everything that touches the OS; the **core** (client) owns everything that thinks. Every model-visible tool is an IPC call the shell can refuse.

## Quickstart

```sh
make bootstrap        # pnpm install + core/.env
make check            # lint + typecheck + tests (TS and Swift) — should be green
make cert             # one-time: dev signing certificate recipe (read it!)
make shell-run        # signed menu-bar app: Tutor (no Dock icon)
make shell-smoke      # hello handshake → permission table → 2-second spotlight overlay
```

Dev loop without the Swift shell:

```sh
make fakeshell        # terminal 1: TypeScript stand-in shell
make core-dev         # terminal 2: core connects, handshakes, draws, gets a typed REFUSED
make demo             # the same, one-shot and in-process (also the CI smoke)
```

Spikes (app-generic diagnostic probes — grant your **terminal** Accessibility once; CLI tools inherit the terminal's TCC identity):

```sh
# One-shot probes.
make spike-ax TARGET=com.apple.TextEdit SECONDS=60
make spike-snapshot TARGET=com.apple.TextEdit MENU="File>Export as PDF…"

# The two acceptance protocols — these produce the results committed under docs/notes/,
# and these are what a second machine runs to replicate.
make spike-ax-run TARGET=<bundle-id> DRIVERS=spikes/drivers/<bundle-id>
make spike-snapshot-run TARGET=<bundle-id> MENU="File>…" RUNS=50

# Author driver sets from what the app actually exposes, not from memory:
./shell/.build/debug/axprobe --bundle-id <id> --dump-menu
./shell/.build/debug/axprobe --bundle-id <id> --dump-tree --depth 6
```

Density verdicts are computed, not typed in: `shell/Scripts/ax-density-verdict.mjs`
scores each action Usable/Partial/Silent from the run's own logs, so the ≥17/20 bar
can be recomputed by anyone from the committed evidence. Its classifier tests run in
CI (`make spike-verdict-test`) and need neither a TCC grant nor the target app.

## The TCC dev loop (read before debugging permissions)

- Permission truth exists **only** via the bundled, signed app (`make shell-run`). A bare `swift run` attributes TCC to your terminal and reports garbage.
- Grants key on **bundle id + code signature**. Sign with the stable `TutorShell Dev` certificate (`make cert`); ad-hoc signing invalidates grants on every rebuild — the symptom is the System Settings checkbox ON while the app reports not-granted.
- When grants wedge anyway: `make reset-tcc`, then re-toggle in System Settings.
- The shell is **never sandboxed**: a sandboxed process cannot hold Accessibility control, post events, or capture arbitrary windows — this is why the Mac App Store is impossible for this product, not declined (docs/execution-plan.md §4).

## Protocol

`protocol/README.md` is the normative message table (JSON-RPC 2.0 subset, semver-negotiated). The zod schemas are the source of truth; the Swift `ShellProtocol` target mirrors them by hand; both sides decode the same golden fixtures in `protocol/fixtures/` so drift fails tests. Change checklist: bump version + table + schemas + fixtures in one commit.
