# @aitutor/protocol — the normative IPC contract

JSON-RPC 2.0 **subset** between the Swift shell (WebSocket **server**, `127.0.0.1:47100/ipc` by default) and the TypeScript agent-core (client). One JSON object per **text frame**; batch arrays rejected; receivers MUST ignore unknown fields (forward compatibility within a major). The zod schemas in `src/` are the source of truth; the Swift `ShellProtocol` target mirrors them **by hand** (codegen from zod is named future work); the golden fixtures in `fixtures/` are decoded by both sides' tests so drift fails CI.

- Version: `PROTOCOL_VERSION = 0.2.0`, `MIN_SUPPORTED = 0.1.0` (semver: major = breaking, minor = additive, patch = docs).
- Negotiation: core's `session.hello` carries `protocolMin`/`protocolMax`; shell answers with the highest version it supports inside the inclusive range, else error `-32001` and close. Both sides negotiate against a *list* — `SUPPORTED_VERSIONS` / `ProtocolInfo.supported`, currently `["0.1.0", "0.2.0"]` — so an N−1 peer pinned to `0.1.0` still handshakes.
- Auth: shell writes `~/Library/Application Support/TutorShell/ipc.json` (0600: port, token, pid, protocol range) each launch. First frame must be `session.hello` carrying the token within 3 s, else close **4401**. Env `AITUTOR_IPC_URL` / `AITUTOR_IPC_TOKEN` override discovery.
- ids: `"c-<n>"` core-originated, `"s-<n>"` shell-originated, monotonic per connection.
- Coordinates: screen **points**, origin **top-left** of the main display. The shell converts from Cocoa's bottom-left.
- Timeouts: requests 5 s default, `overlay.draw` 2 s.

## Errors

Standard JSON-RPC codes plus:

| Code | Name | Meaning |
|---|---|---|
| -32000 | `REFUSED` | Shell declines the action. `data.reason` ∈ `permission_denied \| possession_not_held \| app_not_whitelisted \| forbidden_verb \| learner_interrupt`. The "every tool is a call the shell can refuse" invariant, typed. |
| -32001 | `INCOMPATIBLE_PROTOCOL` | Version negotiation failed |
| -32002 | `INVALID_TOKEN` | Bad/missing token in hello |
| -32003 | `TIMEOUT` | Deadline exceeded (also synthesized client-side) |
| -32004 | `SHELL_BUSY` | Transient; `retryable: true` |

## Methods v0 (core→shell)

| Method | Params | Result |
|---|---|---|
| `session.hello` | `{protocolMin, protocolMax, coreVersion, token, resumeSessionId?}` | `{protocolVersion, shellVersion, sessionId, capabilities[]}` |
| `shell.ping` | `{nonce}` | `{nonce, shellTimeMs}` |
| `permissions.query` | `{}` | `{microphone, screenRecording, accessibility, inputMonitoring}` each `granted\|denied\|not_determined` |
| `overlay.draw` | `{items: [{kind:"spotlight", rect, caption?}], ttlMs?}` | `{drawn}` |
| `overlay.clear` | `{}` | `{}` |
| `input.key` | `{pid, keys}` | `{posted, dryRun}` — **always REFUSED at scaffold** (`possession_not_held`); dev flag logs a dry-run, never posts |

Reserved names (do not redefine): `voice.say`, `board.draw`, `lesson.checkpoint`.

## Methods v0.2 (additive, core→shell)

Defined here, **not yet implemented**: these are schemas and golden fixtures only. A v0.2 shell answers `METHOD_NOT_FOUND` until `AXBridge`/`CapturePipeline` are wired behind them, and advertises `ax` / `input` / `screen` in `session.hello`'s `capabilities` only once the matching handler exists. The v0 table above is frozen and unchanged — that is what makes 0.2.0 a minor.

| Method | Params | Result |
|---|---|---|
| `ax.query` | `{bundleId, scope: application\|focused_window\|menu_bar, maxDepth, maxNodes?, menuPath?}` | `{pid, nodes: AXNode[], truncated}` |
| `ax.act` | `{bundleId, verb: press\|perform\|set_value\|menu\|activate, target?, action?, value?}` | `{performed, matched?: AXNode}` |
| `input.click` | `{pid, point, button?, clickCount?: 1\|2, modifiers?}` | `{posted, dryRun}` — same refusal invariant as `input.key` |
| `screen.observe` | `{region: full_screen\|active_window\|rect, rect?}` | `{atMs, frame, imageAvailable}` |

- **`AXNode`** — `{depth, role, subrole?, title?, identifier?, value?, actions[], frame?}`. `ax.query` answers with a **pre-order list** carrying `depth`, not a nested tree: that is what the shell's `AXElement.descendants(maxDepth:maxNodes:)` yields, and a flat list keeps both mirrors free of recursive-schema machinery. `role` is required — an element whose `AXRole` is unreadable is omitted rather than given an invented role. `frame` is absent when position or size is unreadable (common for menu items). `truncated` is true when the walk stopped on `maxNodes`/`maxDepth`.
- **`AXTarget`** — `{identifier?, title?, role?, menuPath?}`. At least one of `identifier`/`title`/`menuPath` must be present, and the shell requires the match to advertise the AX action being asked for. Per verb: `press`/`perform` need `target` (`perform` also needs `action`, e.g. `AXConfirm`); `set_value` needs `target` + `value`; `menu` needs `target.menuPath` (a title path, e.g. `["File", "Export as PDF…"]`); `activate` needs neither.
- **Addressing is deliberately split.** The AX methods take `bundleId` — the AX channel is app-scoped and a bundle id is what a session whitelist and an audit record can be written against; the shell resolves the pid itself and echoes it in `ax.query`'s result. The synthetic-HID methods take `pid`, because `CGEventPostToPid` takes a pid and because `input.key` froze that shape in v0.
- **`ax.act` vs `input.click`.** `ax.act` goes through Accessibility and never synthesizes input; `input.click` posts synthetic HID and therefore inherits `input.key`'s posture exactly — REFUSED (`possession_not_held`) without a lease, dev flag logs a dry run and never posts. `performed: false` from `ax.act` means the element resolved but the AX API declined; a refusal by the *shell* is always an error frame.
- **Not folded in:** drag (a press-move-release path is a different shape and waits for its own method), and `sleep`, which is a script-driver concern rather than a protocol verb.
- **`screen.observe` returns metadata only, on purpose.** `CapturePipeline.captureOnce()` is still a stub, so the honest answer today is `imageAvailable: false` with the region the shell *would* have captured. No image bytes cross this wire in v0.2; how a frame reaches the model (handle, file path, or side channel) is a later additive minor.

## Events v0 (shell→core notifications)

| Event | Params |
|---|---|
| `permission.status` | `{permission, status}` — pushed on any TCC change |
| `possession.changed` | `{holder: tutor\|learner\|idle, cause: grant\|hardware_interrupt\|release\|panic\|timeout, atMs}` |
| `hardware.interrupt` | `{kind: keyboard\|mouse\|double_esc, atMs}` — low-latency; a `possession.changed` follows if a lease was revoked |
| `workspace.frontmostChanged` | `{bundleId\|null, appName?, atMs}` |

## Change checklist (every protocol change, one commit)

1. Bump `PROTOCOL_VERSION` per semver.
2. Update this table, the zod schemas, and the Swift `ShellProtocol` mirror.
3. **Add** golden fixtures; never edit one that is already in `fixtures/`. Fixtures are frozen per protocol version — the v0.1.0 set is the N−1 regression guard, and a v0.2 wire example lives beside it (`hello-v02.*`) rather than replacing it. Both test suites must stay green.
4. Extend `SUPPORTED_VERSIONS` / `ProtocolInfo.supported` for a minor; drop the old entries only on a major.
