# @aitutor/protocol — the normative IPC contract

JSON-RPC 2.0 **subset** between the Swift shell (WebSocket **server**, `127.0.0.1:47100/ipc` by default) and the TypeScript agent-core (client). One JSON object per **text frame**; batch arrays rejected; receivers MUST ignore unknown fields (forward compatibility within a major). The zod schemas in `src/` are the source of truth; the Swift `ShellProtocol` target mirrors them **by hand** (codegen from zod is named future work); the golden fixtures in `fixtures/` are decoded by both sides' tests so drift fails CI.

- Version: `PROTOCOL_VERSION = 0.1.0` (semver: major = breaking, minor = additive, patch = docs).
- Negotiation: core's `session.hello` carries `protocolMin`/`protocolMax`; shell answers with the highest version it supports inside the inclusive range, else error `-32001` and close.
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

Reserved names (do not redefine): `screen.observe`, `ax.query`, `ax.act`, `input.click`, `voice.say`, `board.draw`, `lesson.checkpoint`.

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
3. Update/add golden fixtures; both test suites must stay green.
