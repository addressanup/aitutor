# design:platform-core

## headline
Build macOS-first as a native Swift shell owning the OS organs (overlay, AX, event tap, capture, TCC, voice I/O) plus a local TypeScript agent-core on the Anthropic SDK tool runner, run demonstrations over deterministic AX/command-set channels with frontier supervision and vision only for verification, and enforce trust — possession, app whitelist, action log — in native code below the model.

## key_decisions
- macOS-first hybrid CONFIRMED: native Swift shell (overlay, AX bridge, CGEventTap, ScreenCaptureKit, TCC, voice plumbing) + local TypeScript agent-core over a localhost WebSocket JSON-RPC IPC; kill pure-Swift, Electron/Tauri, browser-extension-only, and cloud-VM streaming; iOS structurally impossible; Windows (UIA + Agent Workspace) is the second platform with only the shell rewritten.
- Amend the hypothesis: agent-core sits on the plain Anthropic TS SDK + beta tool runner with custom tools (screen.observe, ax.act, input.key, overlay.draw, figma.canvas, voice.say), NOT the Claude Agent SDK — the Claude Code harness (file tools, bash, coding permissions) serves nothing here and the computer-use tool must be wired as a custom tool either way.
- Demonstrations are deterministic-first: lesson scripts execute via AX actions + keystrokes into an installed known FCP command set (CommandPost-proven) + a private Figma plugin bridged over localhost WebSocket; every step has AX-checked pre/postconditions; vision (screenshot + zoom, computer_20251124) is verification and recovery only — never improvised pixel-clicking for taught steps (OSWorld long-horizon ~20-55% forbids it).
- Teaching loop is an explicit persisted state machine (EXPLAIN/DEMONSTRATE/ATTEMPT/FEEDBACK/ADAPT + PAUSED/RECOVERY) with possession (TUTOR/LEARNER/IDLE) as an orthogonal axis enforced in the Swift shell via a possession lease, not merely modeled in the agent.
- Learner touch revokes possession in <100ms: listen-only CGEventTap distinguishes hardware input (kCGEventSourceStateHIDSystemState) from agent-tagged synthetic events (CGEventSourceSetUserData magic number) → safe-stop releases held modifiers, cancels queued events and TTS, transitions to PAUSED.
- Crash recovery mid-demo: append-only SQLite session journal is the source of truth; on relaunch the core re-grounds from an AX snapshot + screenshot against the last verified step postcondition, apologizes in-character, and resumes or replans — never blind keystroke replay.
- Model tiering behind a vendor-agnostic ModelPort: claude-opus-5 for demo supervision, assessment moments, lesson planning, recovery; claude-sonnet-5 for narration and feedback turns; claude-haiku-4-5 for continuous-watch pre-screening (migrating to a local model later); moat lives in curriculum, adapters, learner model, and trust — not raw model capability.
- Prompt-cache strategy: frozen prefix (system prompt, tool defs, signed lesson pack) with 1h-TTL cache_control; volatile session state injected via mid-conversation system messages (supported on Opus 5) so the prefix never invalidates; screenshots in a sliding window after the last breakpoint.
- Voice is a cascaded two-plane pipeline (Anthropic has no voice API): streaming STT (Deepgram Nova-3, Apple SpeechAnalyzer for on-device English) + streaming TTS (Cartesia Sonic English ~90ms TTFB; Gemini 3.1 Flash TTS for Nepali at ~$0.03/min) behind a VoicePort; narration plane independently cancellable for <300ms barge-in without killing the action executor.
- Trust plumbing: staged just-in-time TCC onboarding (Mic → Screen Recording → Accessibility → Input Monitoring), each with plain-language cards, demonstrated value before the next ask, and defined degraded modes on denial; hash-chained append-only local action log surfaced in-app; session app-whitelist enforced in the Swift event-posting function (frontmost bundle-id check) below the model, so prompt injection cannot cross app boundaries.
- Distribution: Developer ID notarized direct-download DMG + Sparkle 2 auto-update — App Store is impossible (sandboxed MAS apps cannot hold Accessibility control or post CGEvents), not a preference; MetricKit + Sentry crash reporting; opt-in count-level telemetry; no screen/audio/keystroke content leaves the machine except model API calls, published in a one-page data map.
- Data local-first in SQLite (learner model, curriculum cache, journals, action log); cloud is only account/licensing plus opt-in sync of a small learner-model+progress JSON; M0 ≈ 37 engineer-weeks ≈ 15-16 calendar weeks for a 2.5-person team, one FCP lesson end-to-end.

## full_markdown

# Platform, stack, and agent-core — decisions

## 1. Platform: macOS-first, Swift shell + local TS agent-core — CONFIRMED, with one amendment

Two-process architecture. A **native Swift/SwiftUI shell** owns every OS organ: the transparent click-through overlay (NSPanel at `.screenSaver` level, `.canJoinAllSpaces`/`.fullScreenAuxiliary` — proven telestration tech, also renders Set-of-Marks labels); the AX bridge (AXUIElement read/act + AXObserver notifications as the semantic feed of learner actions); a listen-only CGEventTap; the ScreenCaptureKit pipeline (per-window, low-fps, `SCScreenshotManager` one-shots); TCC onboarding; and voice I/O plumbing (mic capture, playback, cancellation). A **local agent-core in TypeScript** owns the teaching loop, curriculum, learner model, and model calls. IPC: JSON-RPC over a localhost WebSocket, shell as server, typed message schema, one persistent connection.

**Amendment to the hypothesis:** the agent-core runs on the **plain Anthropic TS SDK + beta tool runner**, not the Claude Agent SDK. The Agent SDK is Claude Code's harness — file tools, bash, coding permissions — none of which a teaching loop uses, and the computer-use tool is not built into it anyway (it's wired as a custom tool either way; platform docs, 2026-08-02). Custom tools exposed to the model: `screen.observe`, `ax.query`, `ax.act`, `input.key/click`, `overlay.draw`, `figma.canvas`, `voice.say`, `lesson.checkpoint` — each one an IPC call the shell can refuse.

**Kills.** *Pure Swift*: re-implements the tool runner, streaming, and caching plumbing Anthropic ships; slows iteration exactly where product risk lives (loop, prompts, curriculum). *Electron/Tauri*: the hard 20% (event taps, AX observers, overlay window levels, SCK) must be native regardless; Electron adds ~200MB of chrome plus its own AX quirks (`AXManualAccessibility`) for an app with almost no UI. *Browser-extension-only*: cannot see or drive Final Cut Pro or any native app — fatally violates principle 1. *Cloud-VM streaming*: teaches on a machine that is not the learner's — no local apps, licenses, media, or environment; adds streaming latency and per-hour VM COGS; breaks P1 and P7. *iOS/iPadOS*: structurally impossible — no cross-app AX control, no event injection, no system overlay; an OS-policy fact, not a roadmap item. **Windows is the second platform**: UIA ≈ AX, and Agent Workspace (Insider, late 2025) is an OS-native tailwind; only the shell is rewritten — agent-core, curriculum, and learner model port unchanged, which is the strongest defense of the split.

**Trade-off:** two languages, a versioned IPC boundary, Swift hiring.
**Constitution:** P1/P2/P3 demand native depth; P7 demands local execution; P6 rides on the portable agent-core.

## 2. Demonstration channel: deterministic-first, vision-verified

A demo that misclicks *teaches the wrong thing*, and long-horizon computer-use reliability is ~20–55% (OSWorld 2.0). So demos execute **lesson scripts over deterministic channels**: AX actions (AXPress/SetValue), keystrokes into an **installed known FCP command set** (the CommandPost-proven channel), and Figma via a **private development plugin + localhost WebSocket bridge** (established talk-to-Figma pattern; app launch/file-open handled by AX). Every step declares pre/postconditions checked against the AX tree; screenshot+`zoom` verification (Haiku/Sonnet) covers what AX can't see (FCP's viewer/timeline canvas). The frontier model *supervises* — sequencing, adaptation, recovery — but does not invent per-click pixel coordinates for taught steps. Improvised model-driven action (`computer_20251124` + beta header, Opus 5) is reserved for recovery and learner-specific detours at 2–6s/action, narrated over.

**Trade-off:** per-app adapters are real engineering; P6 (domain-general) is gated by adapter cost — softened because AX-based *observation* generalizes even where the act-adapter is thin.
**Constitution:** makes P2 and P5 reliable instead of probabilistic.

## 3. The teaching loop as code

Explicit state machine in agent-core: `SESSION_START → EXPLAIN → DEMONSTRATE → ATTEMPT → FEEDBACK → ADAPT → (loop)`, plus `PAUSED` and `RECOVERY`. **Possession is an orthogonal axis** — `TUTOR_POSSESSED / LEARNER_POSSESSED / IDLE` — enforced in the shell, not merely modeled: the event-posting function refuses to act unless the core holds a possession lease, and the lease is revoked by hardware input.

**Interrupts.** Hardware input during `TUTOR_POSSESSED` is detected within milliseconds (`kCGEventSourceStateID`; agent events tagged via `CGEventSourceSetUserData`) → **safe-stop**: cancel queued events, release held modifiers/keys, cancel TTS, transition to `PAUSED`, tutor acknowledges verbally. Voice barge-in cancels only the narration plane, not the executor, unless the learner says stop.

**Persistence & crash recovery.** An append-only SQLite journal records every transition, utterance, action, observation; resume = replay journal to rebuild state. Crash mid-demo: on relaunch the shell reports frontmost app + AX snapshot; the core locates the last step whose postcondition verified, diffs expected vs actual screen state (AX first, screenshot if needed), then **apologizes like a human** ("I lost my place — the timeline shows the cut at 0:12, let me pick up from there") and resumes or replans. Never blind keystroke replay.

**Trade-off:** state-machine rigidity vs model improvisation — states are kept coarse and the model acts freely *within* a state; possession and whitelist remain hard-coded invariants.
**Constitution:** P3 and P7 become mechanisms, not aspirations.

## 4. Model layer

**Vendor-agnostic `ModelPort`** (complete/stream/tool-call + capability flags), Anthropic-primary. Tiering (pricing verified 2026-08):

| Call class | Model | Why |
|---|---|---|
| Demo supervision, assessment moments, lesson planning, recovery | `claude-opus-5` ($5/$25) | Best computer-use grounding; judgment moments |
| Narration turns, feedback dialogue, explain-phase talk | `claude-sonnet-5` ($3/$15; intro $2/$10 to 2026-08-31) | Latency + cost for high-frequency turns |
| Continuous watching pre-screen ("is this AX event/frame notable?") | `claude-haiku-4-5` ($1/$5) | Escalates to Sonnet/Opus at checkpoints |

This is Architecture B (~$5–6/session-hour LLM COGS); the watch tier migrates to a local model → Architecture C (~$3) as capable local VLMs land, without touching the port.

**Prompt cache:** frozen prefix = system prompt + tool defs + signed lesson pack (concept text, step scripts, rubric), `cache_control` 1h TTL (2× write amortized across a session at 0.1× reads; Opus 5's 512-token minimum helps short chunks). Volatile session state is injected via **mid-conversation `role:"system"` messages** (supported on Opus 5) so the cached prefix never invalidates; screenshots ride in a sliding window after the last breakpoint.

**Moat statement:** the vendor could ship a tutor mode; therefore the moat is curriculum packs, per-app adapters, the longitudinal learner model, local trust posture — never raw capability. `ModelPort` keeps Gemini/GPT swappable for cost or vision-latency arbitrage.

**Trade-off:** abstraction tax — Anthropic-specific wins (cache semantics, system-role injection, prompt-injection classifiers on computer-use screenshots) leak through; accept capability-flag escape hatches over lowest-common-denominator.

## 5. Voice: cascaded, two planes

Anthropic has no developer voice API (verified 2026-08), so cascaded is forced — conveniently the architecture that supports Nepali. **Two planes:** the action loop emits step events; a narration plane (Sonnet → streaming TTS) consumes them; TTS streams are independently cancellable, so barge-in never kills the executor. Behind a `VoicePort`: STT = Deepgram Nova-3 streaming ($0.0077/min) primary, Apple SpeechAnalyzer as on-device English cost floor; TTS = Cartesia Sonic (~90ms TTFB) for English, **Gemini 3.1 Flash TTS for Nepali** (~$0.03/min, production-validated), Sarvam Saaras/Bulbul as the Nepali code-mix candidate to validate hands-on. Voice COGS ~$1–2.6/hr.

**Constitution:** P4's mixed-language requirement is why Nepali-capable vendors are load-bearing, not a nice-to-have.

## 6. Trust plumbing

**TCC onboarding — staged, just-in-time, value-first:** (1) **Microphone** at first launch ("talk with your tutor") — simple alert; (2) **Screen Recording** before lesson one ("so I can see what you see") — guided System Settings trip, then immediately *demonstrate* value by narrating the learner's screen; (3) **Accessibility** right before the first demonstration ("so I can drive the mouse when I demonstrate — touch anything and control is instantly yours"); (4) **Input Monitoring** before first observed practice ("so I can see your shortcuts while you try"). Each card: what it enables, when it's used, and what's off (nothing leaves the machine except model calls). **Degraded modes on denial:** no mic → text chat; no screen → explain-only with an honest "I'm teaching blind" banner; no AX → explain+observe, no demos; no Input Monitoring → observation via AX + screen only (keystroke nuance lost). macOS 15's monthly screen-recording re-approval nag is pre-empted in-app so it never reads as a betrayal.

**Action log:** append-only SQLite, hash-chained rows — every synthetic event (timestamp, target app, AX path, action, lesson step, screenshot hash), every permission use, every model-call summary — surfaced in-app as "What your tutor did."

**Whitelist:** each session declares an app allowlist (e.g., FCP + Figma); enforced in the Swift event-posting function via frontmost-bundle-id check before *every* post; violation → refuse + safe-stop + log. This sits **below the model**, so a prompt-injected screenshot cannot make the shell act outside the whitelist; Anthropic's injection classifiers are a second layer, not the enforcement.

**Trade-off:** four scary prompts cost onboarding conversion; staging trades funnel speed for comprehension — accept slower first-session activation.
**Constitution:** P7, made concrete.

## 7. Distribution & ops

**Developer ID + notarized direct-download DMG.** The App Store is not a judgment call: sandboxed MAS apps cannot hold Accessibility control or post CGEvents — the product is impossible there; direct signing also keeps TCC identity stable across updates. **Sparkle 2** auto-update (EdDSA-signed appcast). Crash: MetricKit + Sentry (native + Node). Telemetry: opt-in, count-level only (sessions started/completed, phase durations, crash IDs); no screen, audio, keystrokes, or transcripts leave the machine except model API calls — published as a one-page data map. **Trade-off:** no MAS payment/discovery rails → own Stripe billing + a small licensing endpoint.

## 8. Data

Local-first **SQLite** (WAL, one file per profile): learner model (per-concept mastery, error patterns, pace, language mix), curriculum cache (signed lesson packs from CDN), session journals, action log. Cloud: account/licensing service + **opt-in** sync of learner-model+progress JSON (kilobytes, encrypted); journals and screenshots never sync. Screenshots sent to Anthropic transit under API terms only — disclosed in the data map (Opus 5 carries no Fable-style retention floor).

## 9. Latency budgets

**A. Learner speaks → tutor responds** (target p50 ≤1.0s, p95 ≤1.5s; >2s reads as broken):

| Stage | Budget |
|---|---|
| VAD end-of-speech detection | 150–250ms |
| Streaming STT final (Deepgram/SpeechAnalyzer) | 100–300ms |
| Sonnet 5 first token (cached prefix) | 400–800ms |
| TTS TTFB (Cartesia ~90ms / Gemini Flash) | 90–250ms |
| Audio out buffer | ~50ms |
| **Barge-in acknowledgment** (tap/VAD detect + local TTS cancel + earcon) | **<300ms hard** |

Substantive answers >1s are masked by continuers ("mm, let me look at your timeline…").

**B. Tutor decides → acts on screen:**

| Path | Budget |
|---|---|
| Scripted step (AX action / command-set keystroke) | 30–150ms |
| Postcondition AX verify | 20–100ms |
| Screenshot verify when AX-blind (capture + Haiku) | 0.6–1.2s |
| Model-supervised improvised action (Opus 5, 1080p screenshot) | 2–6s/action (estimate: one model turn per action) |

A 20-step scripted demo lands at ~1.5–3 minutes *including narration* — the pedagogy absorbs the deterministic path's speed; improvisation is narrated over.

## 10. M0 estimate (2–3 engineers; engineer-weeks, estimates)

| Component | EW |
|---|---|
| Shell skeleton + IPC | 2 |
| Overlay renderer (telestration, Set-of-Marks) | 2 |
| AX bridge (read/observe/act, Electron quirk) | 3 |
| ScreenCaptureKit pipeline | 1.5 |
| CGEventTap guard + possession + whitelist + safe-stop | 2 |
| TCC onboarding UX + degraded modes | 2 |
| Voice plumbing (capture, playback, cancel) | 2 |
| Session state machine + journal + resume/recovery | 3 |
| ModelPort + tiering + prompt caching | 2 |
| Demo executor (script runner, verify loop, vision fallback) | 4 |
| Observation pipeline (AX events + foveated screenshots + Haiku screen) | 3 |
| Voice pipeline integration (STT/TTS vendors, narration plane) | 2 |
| Figma blackboard (plugin + WS bridge) | 2 |
| Curriculum format + FCP Lesson 1 content | 3 |
| Notarization + Sparkle + crash/telemetry | 1.5 |
| Integration/QA buffer | 2 |
| **Total** | **≈37 EW → ~15–16 calendar weeks at 2.5 engineers** |

M0 exit: one learner completes FCP Lesson 1 end-to-end — Figma-canvas theory, live narrated demo in FCP, observed attempt with real-time feedback — on their own Mac, with all four permissions granted through the staged flow and a full action log to show for it.