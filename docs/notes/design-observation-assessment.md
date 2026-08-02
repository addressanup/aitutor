# design:observation-assessment

## headline
Observe through free semantic OS events (AX notifications + input taps + artifact polling) and spend screenshots only on six named triggers under a hard 80-look/hour budget; assess the artifact (FCPXML/Figma tree) not the motions; drive a per-skill Bayesian mastery model that gates scaffold fading; interrupt rarely and honestly; make privacy a visible product feature.

## key_decisions
- Two-layer foveated observation: the continuous layer is $0-marginal semantic events (AXObserver notifications, listen-only CGEventTap, app-focus events, adapter state polls); screenshots are exceptions, never the default channel.
- Six deep-look triggers (learner question, claimed completion, rubric checkpoint, error-pattern signature, idle >20s, 90s watchdog) drawn from a prioritized token bucket hard-capped at 80 frontier looks/hour — observation LLM spend <= ~$3/session-hour, inside Architecture B's $8/hr all-in COGS.
- Sonnet 5 is the default deep-look model ($0.004/frame); Opus 5 only on escalation; Haiku pre-screen (1 frame/5s) runs only during active practice.
- Assessment is artifact-ground-truth first: pass/fail comes from declarative assertions over exported FCPXML v1.13 / Figma node-tree JSON; fluency signals (time-to-first-action, hesitation, undo rate, self-correction) are secondary evidence; verbal answers weakest.
- Every lesson carries a versioned YAML rubric: observable_criteria (event-pattern matchers), artifact_assertions (XPath-style over adapter state), fluency_thresholds, and common_errors mapping detection signatures to named remediations.
- Mastery = per-skill-node log-odds Bayesian update with evidence-class weights (artifact ±2.0 logits > fluency ±0.7 > verbal ±0.3), exponential decay toward prior with half-life that grows per spaced success, and review scheduled when p(mastery) decays below 0.6.
- Mastery gates a five-rung scaffold-fade ladder (watch demo -> guided attempt -> prompted attempt -> independent attempt -> transfer task); fading requires p>0.85 with at least one artifact-class evidence, and regressions re-scaffold one rung.
- Feedback policy: 45s productive-struggle timer before any rescue (struggle != idle), max 2 unsolicited interruptions per attempt, immediate interruption reserved for destructive/unrecoverable or compounding errors; everything else queues for the debrief.
- Encouragement is assessment-anchored: the tutor never praises work whose artifact assertions fail — honesty is enforced by wiring praise generation to assessment output, not vibes.
- Privacy as product: session-scoped observation with an always-visible indicator; raw frames analyzed in memory and discarded (never stored, never trained on); semantic summaries are the only persistent record; confirmed macOS SecureEventInput blinds keystroke capture on password fields and the tutor detects and announces it; default app/site blocklist (banking, Mail, Messages, password managers) enforced at the SCContentFilter and AX-attach level; the learner owns any session recording, stored locally.
- Honest limits stated up front: taste/judgment nodes carry a lower confidence ceiling and are assessed by debrief critique, not live; errors that never change app state are covered only probabilistically (watchdog looks + retrieval questions); multi-monitor binds observation to one declared practice display.

## full_markdown

# Observation & Assessment Engine — Design

## 1. Foveated observation: semantic events are the retina, screenshots are the fovea

**Decision.** Observation is two layers. The **continuous layer costs ~$0/hour** and is semantic, not visual: (a) an AXObserver attached to the practice app streaming `kAXValueChanged`, `kAXFocusedUIElementChanged`, `kAXSelectedTextChanged`, `kAXMenuOpened/kAXMenuItemSelected`, `kAXWindowCreated/Moved/Resized`, `kAXUIElementDestroyed` — this alone yields "learner selected Blade from the Trim menu" with no model call; (b) a listen-only CGEventTap (`kCGEventTapOptionListenOnly`, source-state discrimination via `kCGEventSourceStateID`) giving keystrokes, clicks, scrubbing cadence, undo counts; (c) NSWorkspace app/window focus; (d) **adapter state polls**: FCPXML export via the FCP adapter every 3 min and at every checkpoint; Figma node-tree reads over the plugin's localhost WebSocket bridge on demand. These four streams feed a local event normalizer that maintains a rolling "session tape" — timestamped semantic events, no pixels.

The **deep layer** is a screenshot (1280×800 = 1,334 tokens; $0.0040 Sonnet 5 / $0.0067 Opus 5 per frame — platform.claude.com vision docs, 2026-08-02) sent to a frontier model with the current lesson step, recent event tape, and last assessment as cached prefix.

**Trigger set** (priority classes; each look logs its trigger for tuning):
- **P0 — learner asks a question** (voice). Always fires; the tutor must see what the learner sees before answering.
- **P0 — claimed step completion** ("done", or the completion UI). Fires a deep look *and* an adapter artifact pull.
- **P1 — rubric checkpoint**: the event tape matches an expected state transition in the lesson rubric. Artifact assertion runs first; deep look fires only if the assertion is ambiguous (cheaper path preferred).
- **P1 — suspected error pattern**: event-signature match (≥3 undos in 30s; menu wandering across ≥4 menus without action; oscillating AXValue on one control; focus leaving the practice app mid-step) or Haiku pre-screen escalation.
- **P2 — idle beyond threshold**: 20s of no input during an active attempt, throttled to one look per 2 min.
- **P2 — watchdog**: hard ceiling of 90s since last deep look during active practice, so silent divergence (learner confidently doing the wrong thing without tripping any signature) is bounded to ~90s exposure.

**Look budget.** Token bucket, **hard cap 80 deep looks/hour** (reserve: 20 P0, 40 P1, 20 P2; unused P2 tokens roll to P1). Default deep-look model is **Sonnet 5** (~$0.012/look with 20K cached prefix, est. from digest per-call math); escalation to Opus 5 only when Sonnet reports low confidence or the step is flagged high-stakes. Haiku pre-screen at 1 frame/5s runs **only during active practice** (~360 frames/30-min ≈ $0.49). Worst case: $0.49 + 80×$0.015 ≈ **$1.70/hr; budget ceiling $3/hr observation spend**, fitting Architecture B's ~$5–6/hr LLM COGS and ~$8/hr all-in (unit-economics memo, 2026-08-02). On bucket exhaustion, degrade to Haiku + artifact polls and tell the learner assessments will finalize at debrief — never silently degrade.

**Trade-off:** semantic-first observation is blind to anything AX can't expose — chiefly FCP's viewer canvas and skimmer position. The watchdog and Haiku pre-screen are the patch, and they are probabilistic, not complete.
**Constitution:** (3) observation is what makes it a tutor — implemented at a cost that lets it exist; (7) budget enforcement is also a privacy property: the tutor provably looks rarely.

## 2. Honest assessment: grade the work, then the hands

**Decision.** Assessment order is fixed: **artifact → fluency → verbal**, and a claim of mastery must trace to artifact evidence.

- **Artifact ground truth.** FCP: exported FCPXML v1.13 diffed against the rubric (assertions over the spine: clip count, in/out points, transition type/duration, marker placement, role assignment). Figma: node-tree JSON via the plugin bridge (frame structure, constraints, auto-layout properties). Where a lesson ends in an export, the exported file itself is asserted (duration, resolution, codec).
- **Fluency signals** (from the event tape, free): time-to-first-action after instruction; hesitation-gap distribution; undo rate; self-correction (error signature followed by correct state without tutor prompt — scored *positive*, it is the strongest fluency evidence there is).
- **Verbal answers** count least: self-report is unreliable (METR 2025: perceived AI benefit inverted actual; digest).

**Rubric format** — versioned YAML carried by every lesson step:

```yaml
skill_node: fcp.trim.blade_basic
observable_criteria:            # event-pattern matchers, run on the tape
  - id: used_blade_tool
    pattern: menu_select("Trim > Blade") | key("B")
artifact_assertions:            # run on adapter state; partial credit allowed
  - id: three_cuts_exist
    query: fcpxml("spine/asset-clip", count >= 4)
    weight: 1.0
  - id: cut_on_beat
    query: fcpxml("asset-clip[2]/@offset", within(marker_1, 5f))
    weight: 0.6
fluency_thresholds:
  time_to_first_action_s: 15
  undo_ceiling: 4
  hesitation_gap_p90_s: 8
common_errors:
  - id: razor_gap_left
    detect: fcpxml("spine/gap", exists)
    remediation: rem.fcp.magnetic_timeline_explainer
  - id: undo_spiral
    detect: events(undo_count >= 5, window=60s)
    remediation: rem.fcp.slow_demo_replay
checkpoint: {deep_look: on_ambiguous, artifact_pull: always}
```

Named remediations are lesson-authored scripts (mini re-explanation, partial re-demo, or a scaffolded retry), so error→response is deterministic and improvable, not improvised per session.

**Trade-off:** rubric authoring is real editorial work per lesson — this is the curriculum-cost center, and assertion queries couple rubrics to adapter schemas (FCPXML version bumps require rubric CI).
**Constitution:** (5) continuous honest assessment from real performance — this section *is* that principle; (2) demonstrations produce reference artifacts the assertions diff against.

## 3. Mastery model: small Bayesian, evidence-weighted, decaying

**Decision.** Each skill node holds a mastery estimate in log-odds. Update: `logit(p) += w_class × direction × quality`, with **class weights: artifact ±2.0, fluency ±0.7, verbal ±0.3**, per-session cap of ±3.0 per node (prevents one great/awful session from saturating). This is BKT-simple on purpose — explainable to the learner ("here's why I think you've got blade cuts but not J-cuts") and debuggable. **Decay:** p relaxes toward the prior with half-life 7 days, multiplied ×1.8 for each spaced success (consolidation), implementing expanding-interval retrieval practice (Roediger & Karpicke; digest). When decayed p crosses 0.6, the node enters the review queue and the next session opens with a retrieval attempt, not re-teaching.

**Mastery drives adaptation** through a five-rung scaffold ladder: full demo → guided attempt (tutor telestrates targets) → prompted attempt (verbal hints only) → independent attempt → transfer task (same skill, novel footage). **Fade one rung when p > 0.85 with ≥1 artifact-class evidence at the current rung; re-scaffold one rung on two consecutive artifact failures.** Pace, language mix, and explanation depth read the same state: low-p prerequisite nodes trigger back-fill before the ladder advances (cognitive apprenticeship's modeling→coaching→fading, Collins et al.; digest).

**Trade-off:** a hand-tuned log-odds model is crude versus learned knowledge-tracing; we accept miscalibration early in exchange for transparency and zero training-data requirements. Weights become tunable once real session corpora exist.
**Constitution:** (4) personal in every dimension — mastery state is the personalization substrate; (5) fade gates demand artifact evidence, keeping adaptation honest.

## 4. Feedback policy: when to shut up

**Decision.** The tutor's default state during attempts is **silence**.
- **Productive-struggle timer:** no unsolicited help before **45s of active struggle** (input activity present but off-path). Idle is different: 20s idle gets a gentle check-in ("stuck, or thinking?") — that's a question, not a rescue.
- **Interruption budget: 2 unsolicited interruptions per attempt.** Spent budget means everything else queues for the debrief, which the tutor runs after every attempt from the queued observations.
- **Immediate-interrupt whitelist**, exempt from budget: destructive/unrecoverable actions (deleting media/library, overwriting an export) and compounding errors that would invalidate the remainder of the exercise. Everything else can wait; a mistake the learner discovers is worth more than one the tutor prevents.
- **Encouragement calibration:** praise is generated *from assessment output* — effort- and strategy-specific, and structurally impossible when artifact assertions fail ("that attempt didn't land — here's the specific gap" is the honest register). Self-corrections get explicit positive marking.
- **Flow protection:** while the tape shows steady on-path progress, the tutor says nothing at all.

**Trade-off:** a strict budget means some observed mistakes go unmentioned until the debrief, and occasionally the learner flounders 45s longer than a chatty assistant would allow. That's the pedagogy (deliberate practice at edge of ability, Ericsson; the Harvard RCT's brevity/cognitive-load design; digest) — but it will feel withholding to some learners; the struggle timer is a per-learner preference dial with a floor of 20s.
**Constitution:** (3) observation without restraint becomes surveillance-nagging; (7) the learner stays in control of the interaction, not just the machine.

## 5. Privacy architecture as product

**Decisions.**
- **Session-scoped only.** Observation (event tap, AX observers, capture) starts on explicit session start and is torn down at end — verifiable by the OS (the event tap literally doesn't exist outside sessions). A persistent menu-bar indicator plus an on-screen chip in the overlay shows observing/paused; one keystroke pauses everything.
- **Frames are ephemeral.** Screenshots are analyzed in memory and discarded; never written to disk, never used for training. What persists is the **semantic layer**: event tape summaries, assessment records, mastery state — human-readable, learner-inspectable, learner-deletable.
- **Secure input — confirmed and designed around.** macOS activates SecureEventInput on password fields, which blocks event taps from receiving keystrokes (Apple TN2150; Espanso/Keyboard Maestro docs, verified 2026-08-02). The tutor polls `IsSecureEventInputEnabled()`, suspends deep looks while it's active, and *says so* ("password field — I can't and won't see this"). The blind spot becomes a trust proof.
- **Default app blocklist** — banking, Mail, Messages, password managers, browsers on financial domains — enforced at two levels: SCContentFilter app-exclusion (blocked apps never enter any frame) and no AX attachment. Learner-editable, subtractive-only for the defaults requires an explicit override.
- **Learner-owned recording:** optional session recording via SCRecordingOutput, written locally to the learner's disk, never uploaded; useful for their own review and for support disputes.

**Honest statement of quality cost:** local-first observation is worse tutoring today. No local model reads FCP's dense timeline like Opus/Sonnet-class vision; blocklisted context (e.g., the learner's actual client email describing the brief) is invisible; secure-input windows hide typing fluency. We ship the privacy-preserving version and say plainly that a cloud deep-look is what makes feedback sharp — the learner chooses per session between "full tutor" and "degraded local-only observation" (Haiku→local VLM path is the Architecture C migration, ~$3/hr; digest).
**Constitution:** (7) trust as a concept-level requirement — this section is that requirement made mechanical; it deliberately strains (3): maximal observation would be better tutoring, and we bound it anyway.

## 6. What is honestly hard

- **Judgment/taste vs mechanics.** FCPXML proves a cut exists at the marker; it cannot prove the cut *breathes*. Mitigation: taste-class skill nodes carry a **confidence ceiling of 0.7** in the mastery model and are assessed at debrief by frontier critique of exported frames/audio plus comparative prompts ("which of these two versions holds tension longer, and why?") — Socratic, not oracular. Admission: the tutor's taste judgment is a strong film student, not a colorist with 20 years; we label it as opinion, never as assessment.
- **Errors that don't change app state.** Scrubbing the wrong region, misreading a waveform, selecting nothing and believing something is selected — invisible to AX and artifacts. Partial mitigation: hesitation/idle signatures often correlate; the 90s watchdog bounds exposure; retrieval questions ("what's your playhead parked on?") surface silent misconceptions cheaply. Admission: a confident learner doing nothing wrong-looking and nothing state-changing can be wrong for up to ~90s before we can notice, and sometimes we won't notice at all.
- **Multi-monitor.** Decision: the session binds to one **declared practice display** (SCContentFilter per-display); AX and input events remain global, so focus moving to an undeclared display prompts "bring it to the practice display, or rebind me." Telestration renders only on the bound display. Admission: workflows that are genuinely two-monitor (viewer on one, timeline on the other) get a degraded tutor in v1 — dual-display capture doubles look cost and splits overlay mapping; it's a fast-follow, not a launch feature.

**Cross-cutting risk:** the entire engine presumes the adapter layer (FCPXML export, Figma bridge, AX richness proven by CommandPost; digest) stays stable across app updates. Rubric CI against pinned app versions plus a semantic-layer-only fallback mode is the containment plan.