# design:demonstration-control

## headline
Build a verification-first Demonstration Engine: semantic lesson steps execute down a T2-adapter / T1-Accessibility / T0-vision capability ladder with mandatory postcondition checks and pedagogical (never faked) fallbacks, rendered watchable by a telegraph-first overlay language, under a hardware-grounded possession state machine that pauses the tutor within 100ms of any real learner input.

## key_decisions
- Confirm semantic step plans + capability ladder (T2 app adapters, T1 macOS AX, T0 computer-use), with one amendment: verification is the spine — tiers act differently but all verify identically, and possession gating sits below the executor at the event layer.
- Scripted demo spine, live model confined to three roles: step repair within fixed postconditions, learner Q&A, and GUIDE-mode improvisation — no free-driving long demos (OSWorld 2.0 long-horizon ~20-55% forbids it).
- Step lifecycle PLAN → TELEGRAPH → ACT → VERIFY → NARRATE; nothing is touched that was not first highlighted; success is never narrated before the postcondition passes; ≤2 retries, second retry may drop a tier.
- Failed demo steps convert to learner participation ("you click it for me — the blue icon, top right"), verified by the same postcondition via AXObserver — failure becomes pedagogy, never pretense.
- One click-through screenSaver-level overlay with an 8-primitive API: spotlight, arrow, caption, marks (Set-of-Marks), cursorGhost, pulse, badge, clear; cursor motion eased and speed-capped (~900 px/s est., ≥350ms travel).
- Two-plane architecture: action executor emits step events; separate narration plane (LLM→streaming TTS) speaks only at step boundaries (Mayer segmenting) and is independently cancellable for barge-in.
- Four possession modes mapped to cognitive apprenticeship: WATCH=modeling, TOGETHER=scaffolding (per-action consent), GUIDE=coaching, TRY=fading; the tutor may request control but can never take it — every grab requires an explicit learner grant plus announced handover.
- Interrupt guarantee grounded in CGEventTap facts: listen-only tap at kCGHIDEventTap classifies kCGEventSourceStateID==HIDSystemState(1) and absence of our CGEventSourceSetUserData magic as real learner input → executor gate flips in-process, synthetic queue aborts, in-flight T0 actions are discarded at the gate; end-to-end pause ≤100ms with visible badge flip and audible tick.
- Drag-abort semantics: the only >50ms atomic synthetic sequence is a drag; on interrupt it posts mouse-up at current position, marks the step FAILED, and VERIFY runs — the tutor never claims an aborted drag completed.
- Double-Esc (≤400ms, hardware-sourced) = FULL STOP: kill event posting, release held modifiers, clear overlay, drop to TRY, resume only on explicit re-invitation; scope whitelist of bundle IDs checked before every single action — the tutor never acts outside session-whitelisted apps, including during repair.
- Tier step-success design targets: T2 ≥99.5%, T1 ≥97%, T0 ≥90% per verified step; WATCH demos permitted only when compound predicted success ≥95% — therefore T0-only apps default to GUIDE-mode teaching (tutor narrates and overlays, learner drives).
- Fluency demonstrations (speed-is-the-point, e.g. J-K-L trimming) must run on T2 deterministic channels; T0 is banned for fluency demos but acceptable — even pedagogically superior — for concept-paced steps where 2-6s/action reads as deliberate.

## full_markdown

# Demonstration Engine & Control-Handoff Protocol — Design

## D1. Action architecture — hypothesis confirmed, one amendment

The semantic-plan + capability-ladder hypothesis survives attack, amended: **verification, not action, is the engine's spine**. Tiers act through different channels, but every step verifies through the same postcondition contract, and possession gating lives *below* the executor at the OS event layer, so no code path can act while the learner has control.

**Step IR.** A lesson is an authored DAG of semantic steps: `{id, intent(verb, target, params) — e.g. append_clip(clip:"interview_02", at:playhead), preconditions, postconditions (AX predicate and/or vision-assert spec), narration slots (before/after), pedagogy meta (concept_id, concept|fluency flag, learner-practice conversion script), tier bindings resolved at runtime}`.

**Capability ladder** (all facts per computer-control digest, 2026-08-02):
- **T2 adapters — deterministic, ms latency.** *Figma:* private development plugin ("Import plugin from manifest", no review) whose UI iframe holds a WebSocket to the tutor's localhost daemon — the established bridge pattern; the plugin draws the blackboard (createFrame/createText/loadFontAsync, viewport.scrollAndZoomIntoView). Launching Figma/opening files is T1 (plugins can't). *Final Cut Pro:* installed known command set + CGEvent keystrokes (the CommandPost-proven channel), FCPXML v1.13 import for prepared exercise projects only (import creates new items, never live mutation), FCP's rich AX tree for grounding and verification. *Resolve:* Python scripting API when Studio ($295) is detected; free tier is treated as a T1 app (external scripting Studio-only since 19.1).
- **T1 macOS Accessibility — semi-deterministic, ms latency.** AXUIElementPerformAction (AXPress/AXShowMenu/AXPick), AXUIElementSetAttributeValue on grounded elements; AXManualAccessibility=true for Electron apps.
- **T0 computer-use — probabilistic, 2–6s/action (est., one model turn per action).** `computer_20251124` + beta header on Claude Opus 5, client-side executor, 1080p screenshots, `enable_zoom:true`, Set-of-Marks overlay labels injected to replace raw-coordinate clicking, instruction-before-image ordering per Anthropic guidance.

A per-app capability registry maps (bundle_id, verb) → highest available tier; a step may bind different tiers for act vs verify (typical FCP step: act via T2 keystroke, verify via T1 AX read; vision-assert only where AX is blind — the viewer/timeline canvas pixels).

**Step lifecycle: PLAN → TELEGRAPH → ACT → VERIFY → NARRATE.**
1. **PLAN** (silent): check preconditions against live AX state; on drift, bounded repair; ground the target; choose binding.
2. **TELEGRAPH** (600–900ms): overlay spotlights the target and shows the caption *before* the cursor arrives. Invariant: nothing is ever touched that wasn't first highlighted.
3. **ACT**: execute the binding. Every synthetic event is stamped via CGEventSourceSetUserData magic number so the interrupt tap distinguishes self from learner.
4. **VERIFY** (mandatory, all tiers): AX predicate first (ms, free), screenshot+zoom vision assert only where AX can't express the postcondition. ≤2 retries; retry 2 may drop one tier.
5. **NARRATE**: the narration plane — a separate LLM→streaming-TTS loop consuming step events (two-plane design per voice digest) — speaks intent at TELEGRAPH and outcome only after VERIFY passes; silence or continuers during ACT; learner-paced "ready for the next bit?" checkpoints every 2–4 steps (Mayer segmenting).

**Scripted determinism vs live judgment.** The demo spine is scripted. The live model gets exactly three jobs: (a) *repair* — when VERIFY fails or drift is detected, it re-plans within the current step's postcondition and may not change the postcondition; (b) *Q&A* — barge-in questions answered from current AX+screenshot context, then resume; (c) *improvisation in GUIDE mode*, where the learner drives so model latency and fallibility cost nothing physical. Rationale: OSWorld-Verified ~85% short-task vs OSWorld 2.0 ~20–55% long-horizon (arXiv, 2026, medium confidence) — a free-driven 40-step demo fails visibly and often.

**Pedagogical fallback.** When a step exhausts retries, the engine runs the step's conversion script: "It's not letting me — you do it for me. The blue Inspector icon, top right." Overlay spotlights the same target; AXObserver verifies the same postcondition when the learner acts. The lesson advances either way; failure becomes participation, and retrieval practice besides.

**Trade-off:** the verification contract roughly doubles per-step machinery and forces an authoring pipeline (postconditions must be written per step); it buys the only thing that matters — a demo that misclicks *teaches the wrong thing*, and a verified engine cannot lie to itself.
**Constitution:** P2 (demonstration first-class), P5 (assessment from real state, not model self-report), P3 (the same AXObserver channel serves observation).

## D2. Watchability — the overlay visual language

One click-through NSPanel (level .screenSaver, ignoresMouseEvents, [.canJoinAllSpaces, .fullScreenAuxiliary], .nonactivatingPanel — proven telestration technique, works over fullscreen Spaces). The entire visual language is 8 primitives:

```
spotlight(target, dim=0.45)   // darken everything but target
arrow(to, from=auto)          // animated pointer
caption(text, step_n, anchor) // one-line step banner, large type
marks(elements[]) → labels    // Set-of-Marks numbered badges (GUIDE hints + T0 grounding, one surface)
cursorGhost(path)             // eased trail + halo tint during tutor motion
pulse(target, keychip?)       // action confirmation flash; "⌘B" chip for keystroke steps
badge(mode)                   // persistent possession indicator + stop button — never hidden
clear(scope)
```

Cursor humanization: the real cursor moves via interpolated mouse-moved CGEvents on an ease-in-out curve, speed-capped (~900 px/s est., ≥350ms minimum travel) so the eye tracks it. Keystroke-driven T2 actions are otherwise invisible — `pulse` with a key chip makes them watchable. `badge` doubles as the mode indicator and tint source: tutor-driven motion is visually unmistakable from learner motion.

Narration gating: talk at boundaries only; barge-in speech cancels TTS <300ms (voice digest) and pauses the executor at the current step boundary; hardware input pauses it immediately (D3).

**Trade-off:** deliberate pacing makes a 12-step demo take ~2–4 minutes even on ms-fast T2 channels — slower than a YouTube clip. That is the point: Mayer's segmenting says learner-paced chunks beat continuous streams; we are not optimizing throughput, we are optimizing encoding.
**Constitution:** P2, P4 (pace is an adaptation dial — telegraph duration and checkpoint frequency shrink as the learner advances).

## D3. Control-possession protocol — principle 7 made mechanical

**Modes → cognitive apprenticeship:** WATCH = modeling, TOGETHER = scaffolding, GUIDE = coaching, TRY = fading (Collins, Brown & Newman). Default per-concept arc WATCH→TOGETHER→GUIDE→TRY; mode selection is a first-class adaptation surface.

**State machine.** Possession ∈ {TUTOR_DRIVING, LEARNER_DRIVING, SHARED_PENDING, SUSPENDED, STOPPED}.
- LEARNER→TUTOR **only** via explicit grant ("you drive" / Watch button); tutor announces ("Taking the mouse — eyes on the timeline"), badge flips, chime, 1s grace before the first event. **The tutor may request control; it can never take it.**
- TUTOR→LEARNER via handover phrase ("Your turn — keyboard's yours") + badge + chime; or involuntarily via interrupt.
- **TOGETHER:** every tutor micro-act is a proposal — telegraph fires, caption reads the action + "Return to approve"; approval executes exactly one step, then possession reverts. 10s timeout = declined → converted to a guided learner action.
- **Interrupt guarantee (grounded in digest facts):** a listen-only CGEventTap at kCGHIDEventTap classifies each event: `kCGEventSourceStateID == kCGEventSourceStateHIDSystemState (1)` ∧ userData ≠ our magic ⇒ genuine learner input. Tap callback latency is milliseconds; suppression is in-process — the executor gate flips before the callback returns, the synthetic queue aborts (<10ms), and any in-flight T0 model turn's returned action is discarded at the gate, not executed. End-to-end pause budget **≤100ms**, acknowledged visibly (badge → "You have control" within one frame, spotlight clears) and audibly (tick + TTS truncation). Atomicity rule: no synthetic sequence except drags exceeds ~50ms; an interrupted drag posts mouse-up at the current position, marks the step FAILED, and VERIFY runs — the tutor then repairs or hands over honestly. This is a UX guarantee, not a security boundary (source-ID isn't spoof-proof); the security boundary is TCC + scope.
- **Panic:** double-Esc (two hardware Esc ≤400ms) from any state → STOPPED: event posting killed, synthetic key-ups for any held modifiers, overlay cleared to badge-only, mode TRY; resumable only by explicit re-invitation. The badge's stop button does the same by click.
- **Scope guarantee:** the session contract (spoken + shown at start) whitelists bundle IDs (e.g., FCP, Figma, lesson folder in Finder). The executor checks the frontmost app *and* the target element's owning app before every ACT; non-whitelisted focus (stray dialog, notification, Space switch) hard-pauses and asks. The tutor never acts in Mail, browsers, or System Settings — including during repair. Anthropic's built-in injection classifiers on T0 screenshots add a second layer.

**Trade-off:** per-action consent makes TOGETHER slow and slightly ceremonial; explicit-grant-only means the tutor sometimes waits awkwardly for permission it pedagogically "should" have. Accepted: trust is a concept-level requirement, and a tutor that ever surprises the learner's hands loses the session and the category.
**Constitution:** P7 fully realized; P3 (SUSPENDED is also an observation signal — the learner grabbing the mouse mid-demo *is* data); mild strain on P4 (ceremony can't be adapted away below a floor — the floor is deliberate).

## D4. Failure taxonomy and the honesty ladder

**Classes:** F1 grounding-miss, F2 action no-op, F3 postcondition mismatch, F4 pre-step drift, F5 learner interrupt, F6 capability missing (TCC revoked, app version, Resolve-free).

**Tier step-success design targets** (targets to instrument from day one, not measurements): T2 ≥99.5%, T1 ≥97%, T0 ≥90% per verified step (basis: OSWorld-Verified ~85% per-*episode* frontier implies higher per-step with verify loops; medium confidence). **Gating rule:** a segment may run as a WATCH demo only if predicted compound success (∏ of step targets) ≥95%. Corollaries: T0-only apps default to **GUIDE-mode teaching** — tutor narrates and overlays marks, learner drives; T0 WATCH demos are capped at ≤5-step segments. Fluency demonstrations (speed is the content: J-K-L trimming feel) must be T2; **T0 is banned for fluency demos** — 2–6s/action would demonstrate hesitation, the opposite of the lesson.

**Honesty ladder** (strict order, no silent skipping): (1) retry same tier ≤2 → (2) drop tier → (3) convert to learner-performed step → (4) show-don't-do: static expected-state image from lesson assets + narration → (5) defer: "I can't demonstrate this here today — flagged; let's continue," logged. Rules: success narration only after VERIFY; failures are named as failures in teaching voice; the learner's assessment record distinguishes *demonstrated* vs *described* per concept, so capability claims stay grounded in what actually happened on screen.

**Constitution:** P5 (honest assessment applies to the tutor itself), P6 (the ladder — not adapters — is what makes the product domain-general: any app teachable at *some* rung).

## D5. The three demanded trade-offs, decided

**Adapters vs generality.** Decided: adapters for the two launch apps (Figma blackboard, FCP), T1/T0 general path everywhere else. Cost: est. weeks of engineering per adapter, version fragility (FCP command-set and AX-tree changes; mitigate with a version-pinned command set installed at onboarding and CI against FCP updates). Buy: converts a ~85% probabilistic actor into ≥99% deterministic where demos must be flawless, and makes fluency demos possible at all. Generality survives because an unadapted app degrades to GUIDE, not to failure.

**Scripted vs live demonstration.** Decided: scripted spine, live repair. Cost: a lesson-authoring pipeline and less spontaneity — the tutor cannot improvise a novel 30-step WATCH demo on request (it offers GUIDE instead). Buy: watchability, honesty, predictable latency, and demos that survive OSWorld-2.0-class long-horizon fragility.

**Where latency hurts vs helps.** Model latency (2–6s/action) is fatal for fluency demos and for TOGETHER responsiveness (consent prompts must appear instantly — always T2/T1). It is *pedagogically fine, often better,* for concept steps: the telegraph-pause-act-verify rhythm is deliberate teaching pace, and narration fills it. Rule of thumb: anything the learner should later do fast must be demonstrated fast (T2); anything the learner should understand may be demonstrated slow — and deliberately is.

**Top risks:** FCP/macOS update fragility on T2/T1 (mitigation above); macOS 15+ monthly Screen Recording re-approval nags eroding trust theater (fold the re-approval into the session-start ritual); TCC onboarding friction (two manual System Settings trips — script it as the trust story, per computer-control digest); Figma sandbox/IPC policy changes breaking the WebSocket bridge (fallback: blackboard on our own overlay canvas, T1-driven).