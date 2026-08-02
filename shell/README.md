# shell — the Tutor's macOS organs

Native Swift shell: a menu-bar app that owns everything touching the OS — the overlay, Accessibility bridge, event-tap guard, screen capture, permissions, and voice I/O — and exposes them to the TypeScript agent-core over a localhost WebSocket (this side is the **server**). Every model-visible action is an IPC call the shell can refuse.

**Domain-open:** no app is special-cased. `axprobe` and `snapshot-spike` take a `--bundle-id`; the per-app control registries are data, added later.

## Build & run

```sh
swift build                 # or: make shell-build
swift test                  # or: make shell-test — decodes the shared protocol fixtures
make cert                   # one-time: create the stable dev signing certificate (read it)
make shell-run              # assemble + sign build/Tutor.app, launch the menu-bar item
make shell-smoke            # zero-dep client: handshake → permission table → 2s spotlight
```

Menu-bar item (graduation-cap) shows the four TCC statuses (queried, never prompted) and the IPC port. On launch the app writes `~/Library/Application Support/TutorShell/ipc.json` (0600: port, per-launch token, pid, protocol range) — the core's discovery + auth handoff.

## Targets (one organ each)

| Target | Role | State at scaffold |
|---|---|---|
| `ShellProtocol` | JSON-RPC types, semver negotiation — the Swift mirror of `@aitutor/protocol` | functional + tested |
| `IPCServer` | WebSocket server (Network.framework), auth, method dispatch | functional |
| `Permissions` | query-only TCC snapshot (no prompts) | functional |
| `Overlay` | click-through spotlight panel (`.screenSaver` level, `sharingType = .none`) | functional (spotlight + clear only) |
| `AXBridge` | `AXUIElement` read/act, `AXObserver` → `AsyncStream` (the canonical C-callback pattern), menu walking | functional; powers the spikes |
| `EventTapGuard` | possession gate (`OSAllocatedUnfairLock`), the `postKey(pid:…)` choke point, synthetic-tag machinery | gate + choke point real; tap not started |
| `CapturePipeline`, `VoiceIO` | ScreenCaptureKit / mic-audio plumbing | stubs |
| `TutorShellApp` | menu-bar app wiring it together | functional |
| `axprobe`, `snapshot-spike` | week-1 diagnostic spikes | functional |

## The TCC dev loop (read before debugging permissions)

- **Permission truth exists only via the signed `.app`** (`make shell-run`). A bare `swift run Tutor` attributes TCC to your terminal and reports garbage.
- Grants key on **bundle id + signature**. `make cert` creates the stable `TutorShell Dev` certificate; ad-hoc signing (the loud-warning fallback) invalidates grants every rebuild — the symptom is the System Settings checkbox ON while the app reports not-granted.
- Wedged grants: `make reset-tcc`, then re-toggle in System Settings.
- **Never sandboxed, hardened runtime off for dev** (`Config/dev.entitlements` = `get-task-allow` only). A sandboxed process can't hold Accessibility control or post events — the reason the Mac App Store is impossible for this product, not declined.

## Spikes (the M0 week-1 de-risking probes)

Grant your **terminal** Accessibility once (System Settings → Privacy & Security → Accessibility) — CLI tools inherit the terminal's TCC identity, so the spikes work unbundled.

```sh
make spike-ax TARGET=com.apple.TextEdit SECONDS=60     # AXObserver notification density
make spike-snapshot TARGET=com.apple.TextEdit MENU="File>Export as PDF…"   # menu-drive + save-sheet timing
```

`axprobe` logs per-notification counts while you drive the app by hand — the data that decides whether the hit-testing fallback is needed for a given app's canvas. `snapshot-spike` drives a menu action via AX and times it against the 2–4 s ritual budget. Rehearse on TextEdit before pointing either at a pro app (which needs a document open for its export menu to resolve).

## Concurrency posture (Swift 6, strict)

`TutorShellApp`/`Overlay` compile with default `MainActor` isolation; systems targets are `nonisolated`. C callbacks (AXObserver, later CGEventTap) use the **one sanctioned pattern**: a dedicated `RunLoopThread` + an `@unchecked Sendable` box holding an `AsyncStream.Continuation`. The possession gate is a synchronous `OSAllocatedUnfairLock`, never an actor — the ≤100 ms hardware-interrupt budget forbids `await` in the tap path.
