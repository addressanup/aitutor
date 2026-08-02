# design:curriculum-adaptation

## headline
Make every lesson a declarative, model-portable Lesson Spec — semantic intents with machine-checkable AX/FCPXML checkpoints, rubrics written in the observation engine's own event grammar — and make adaptation real via a per-node BKT learner model and a five-level scaffolding fade whose "assistance-per-task trending down" is the product's core health metric.

## key_decisions
- Lesson Spec is YAML with semantic intents (fcp.ripple_trim), never coordinates or model prompts; verify predicates are machine-checkable against the AX tree or FCPXML diff, so specs survive engine/model swaps.
- Rubrics are predicates over the observation engine's event grammar (AX event stream + end-state FCPXML diff), not vision-model vibes — the same grammar the observer emits is the grammar authors write.
- Board plans are authored once in an abstract Board IR; a built-in overlay/canvas board is the universal renderer, the Figma plugin (localhost WebSocket bridge) is a detected upgrade; telestration during demo/practice is always the built-in overlay.
- FCP skill graph v1: 5 units / 21 lessons from zero to exported video; drill-heavy core (Unit 3, The Cut), capstone lesson runs at scaffold level L0 as the honest assessment.
- Learner model: per-skill-node mastery via simplified Bayesian Knowledge Tracing updated from observed rubric outcomes; pace factor; language profile with observed code-switch ratio; affect estimated from behavioral signals + prosody; stated goal.
- Cold start is placement-by-doing: four observed micro-tasks (~8 min) in real FCP initialize unit priors — no quiz, per constitution principle 5.
- Scaffolding fade: five help levels (L4 full demo -> L3 partial demo -> L2 hint overlay -> L1 verbal nudge -> L0 nothing); start level set by mastery band, drop one after each low-assist success, raise one only on 2 consecutive fails or frustration spike; hard cap of one full demo per skill per session.
- Assistance-per-task (weighted help events) is declared the core anti-dependence metric; a flat or rising slope over 3 sessions forces the scaffold cap down — this operationalizes the concept's inversion against the deskilling evidence.
- Language policy: mirror the learner's observed Nepali-English code-switch ratio within ±10 points, keep tool vocabulary in English (FCP's UI is English), shift 20 points toward primary language when frustration > 0.6.
- v1 authoring: hand-authored by a domain-expert + learning-engineer pair at an estimated 20-30 h/lesson (falling to ~12-15 h with templates); full 21-lesson FCP course ≈ 350-550 hours, one pair, ~1 quarter.
- v2 Lesson Compiler: instrumented capture (ScreenCaptureKit video + AXObserver event log + keystroke tap + ASR) -> alignment -> segmentation into explain/demo moves -> intent lifting with auto-generated verify predicates from AX/FCPXML before-after diffs -> LLM drafts narration/board/rubric/hints -> human review UI + engine replay test; target 3-6 h review per lesson (4-6x cheaper).
- v3 marketplace: experts publish Lesson Spec courses that execute as live tutors; the replay test is the quality gate; the shared error-pattern library and longitudinal learner models are the platform network effect.

## full_markdown

# Learning-systems design: lessons as data, adaptation as rules

## 1. The Lesson Spec (the strategic asset)

**Decision:** One YAML document per lesson, semver-versioned, containing zero model prompts and zero screen coordinates. Actions are *semantic intents* resolved at runtime by a per-app executor library (AX action, else keystroke via an installed known FCP command set — the CommandPost-proven channel). Checkpoints and rubrics are *machine-checkable predicates* over the AX tree, the observer's event stream, or an FCPXML diff — never "the model thinks it looks right." That is what makes the spec model-portable: swap Opus for Sonnet (or a non-Anthropic engine) and only execution reliability changes; the content, checkpoints, and grading are untouched.

```yaml
lesson: fcp.u3.l3          # "Trim: ripple & roll"
version: 3.2.0             # engine pins major version
skills:
  teaches: [trim.ripple, trim.roll]
  requires: [timeline.blade, timeline.select, playback.jkl]
explain:
  - id: why-trimming
    say: {core: "…", deep: "…"}          # depth variants; language resolved at runtime
    board:                                # abstract Board IR — renderer-agnostic
      - {op: frame, title: "Two kinds of trim"}
      - {op: clips, items: [A, B]}
      - {op: arrow, from: A.end, to: B.start, label: "ripple pulls everything left"}
demo:
  - id: d1
    intent: fcp.select_edit_point {clip: interview_2, edge: end}
    channels: [ax, keys]                  # executor picks channel; pixels are last resort
    narrate: "Watch the pointer change — that's the ripple tool."
    verify: {ax: "timeline.selection == edit_point", timeout_s: 5}
  - id: d2
    intent: fcp.ripple_trim {delta_frames: -12}
    verify: {fcpxml: "project.duration -= 12f"}
practice:
  starter_assets: {bundle: "fcp-lib://u3-interview.fcpbundle", opens_to: "Rough Cut 1"}
  task: "Remove the 3 marked pauses with ripple; fix one cut with roll."
  time_box_min: 12
rubric:                                   # written in the observer's event grammar
  - {crit: used_ripple_not_delete, detect: "events(trim.ripple) >= 3", weight: 0.4}
  - {crit: duration_target, detect: "fcpxml.duration in [55s,65s]", weight: 0.3}
  - {crit: no_gaps, detect: "fcpxml.gaps == 0", weight: 0.3}
hints:                                    # ladder maps to scaffold levels
  - {level: L3, do: partial_demo, step: d1}
  - {level: L2, do: overlay, target: "edit point, clip 2", say: "start here"}
  - {level: L1, say: "Which tool moves everything after the cut?"}
remediate:
  - {on: pattern.deleted_instead_of_trimmed, goto: explain.why-trimming, then: retry}
  - {on: pattern.gap_left, inject: micro_drill.close_gaps_x3}
review:
  - {due_days: [2,7,21], task: "ripple 2 cuts, fresh clip", pass: "events(trim.ripple)>=2 && assist==0"}
```

Starter assets are first-class: a prepared `.fcpbundle` with footage, keyworded and marked, so practice starts in seconds — no "first, download some clips" dead air. The rubric grammar is identical to what the observation engine emits (typed events `(verb, object, params, t)` from AXObserver notifications plus end-state FCPXML export-and-diff), so authors and the observer literally share a schema file.

**Trade-off:** semantic intents require building and maintaining a per-app executor library (FCP first); a pixels-only approach would need no library but would rot with every UI change and be unverifiable. **Constitution:** serves 2 (demonstration first-class), 3 (observation), 5 (assessment from real performance), 6 (the spec format is domain-general; only the executor is per-app).

## 2. Board strategy

**Decision:** Author board plans once in the abstract Board IR above; render through (a) a **built-in board** — a native canvas window plus a transparent telestration overlay (NSWindow at `.screenSaver` level, click-through, all-Spaces; the confirmed-viable technique) — as the universal default, and (b) a **Figma adapter** — development plugin whose UI iframe holds a localhost WebSocket to the tutor (the established bridge pattern), with app-level automation opening Figma and the file first — as a detected upgrade. Selection rule: use the adapter iff Figma is installed ∧ the bridge handshakes in <5 s ∧ the lesson's `board_affinity` permits ∧ the learner hasn't opted out; otherwise built-in, silently. Two hard rules: telestration during demo and practice is *always* the built-in overlay (third-party surfaces are too slow/fragile for real-time annotation), and no lesson may ever block on a third-party board. When the subject *is* Figma, the board is Figma by definition and the signature move is mandatory.

**Trade-off:** we ship and own a rendering surface, and the "professor walks into your own studio" purity is diluted on machines where the built-in board is used. **Constitution:** strains principle 1 (real environment) knowingly; the resolution is that the *practice* app is always real — the board is pedagogy furniture. Serves 7: a first-party surface never touches learner files.

## 3. FCP skill graph v1 (5 units, 21 lessons)

- **U1 Interface & the library model** — L1.1 What editing is; FCP's library/event/project mental model (EXPLAIN); L1.2 Interface tour: browser, viewer, timeline, inspector (DEMO); L1.3 Creating libraries/events/projects (DEMO); L1.4 Playback & navigation: JKL, skimming, marking (DRILL).
- **U2 Import & organize** — L2.1 Importing: leave-in-place vs copy, media management (EXPLAIN+DEMO); L2.2 Keywords & ratings (DRILL); L2.3 Smart collections (DEMO); L2.4 The review-and-select workflow (DRILL).
- **U3 The Cut** (the heart; drill-dense) — L3.1 Append/insert/connect/overwrite (EXPLAIN+DEMO); L3.2 Blade & join (DRILL); L3.3 Ripple & roll trims (DRILL — the keystone lesson sketched above); L3.4 Slip & slide (DRILL); L3.5 The magnetic timeline & connected clips, why FCP is different (EXPLAIN).
- **U4 Timeline ops & audio** — L4.1 Connected B-roll & cutaways (DEMO); L4.2 Audio levels, fades, keyframes (DRILL); L4.3 Music, ducking, noise cleanup (DEMO); L4.4 Transitions & titles, restraint as craft (DRILL).
- **U5 Color & export** — L5.1 Color correction basics: wheels, exposure/saturation (EXPLAIN+DEMO); L5.2 Shot-to-shot consistency (DRILL); L5.3 Export: formats, compression, share destinations (EXPLAIN+DEMO); L5.4 **Capstone**: full edit of fresh provided footage to exported video, run at scaffold L0 (DRILL/ASSESSMENT).

Prerequisite edges follow unit order except U2↔U3 partial parallelism (blade needs only L1.4 + L3.1). **Trade-off:** 21 lessons is deliberately narrow — no multicam, no effects-heavy work — to reach "real exported video" fast; breadth is v1.1 expansion, not v1 scope.

## 4. The learner model

**Decision:** a per-learner JSON document the engine reads/writes every session:

```json
{"goal": "publish YouTube vlogs",
 "mastery": {"trim.ripple": {"p": 0.62, "obs": 9, "last": "2026-08-01"}},
 "pace": 1.15,
 "lang": {"primary": "ne", "secondary": "en", "cs_ratio": 0.35, "tech_terms": "en"},
 "affect": {"confidence": 0.6, "frustration": 0.2,
            "signals": ["retry_rate","undo_bursts","pause>10s","prosody_flags"]},
 "assist": {"trim.ripple": [3.0, 2.2, 1.0, 0.4]}}
```

Mastery is simplified Bayesian Knowledge Tracing per skill node — each rubric-criterion outcome is an observation; defaults p_learn 0.2, p_slip 0.1, p_guess 0.05, tuned once data exists. `cs_ratio` is *measured* from the learner's own speech (STT via Sarvam Saaras, which handles Nepali code-mixing), not asked. Frustration is inferred from behavior (undo bursts, retry loops, long silences, prosody flags) plus explicit statements — never from self-report alone, per the METR lesson that self-perception is unreliable.

**Cold start = placement by doing:** four observed micro-tasks in real FCP (~8 min total): open the provided library and play a clip; append three clips to a new project; blade out a marked section; raise a clip's volume 3 dB. Each maps to a unit prior; performance (completion, hesitation, channel used — menu vs shortcut) initializes mastery bands. No quiz, ever. **Constitution:** 4 and 5 directly.

## 5. Adaptation policies (concrete rules)

**Scaffold levels:** L4 full demo → L3 partial demo (tutor does first half, learner finishes) → L2 hint overlay (telestration arrow + one sentence) → L1 verbal nudge (Socratic question) → L0 nothing.
**Start level by mastery band:** p<0.3→L4; 0.3–0.6→L3; 0.6–0.85→L2; ≥0.85→L1/L0.
**Fade (decay rule):** after any task with assist score <0.5, drop one level for that skill. Raise one level only after 2 consecutive failures *or* frustration >0.7. Hard cap: one L4 full demo per skill per session — a second request gets L3 with the learner's hands on the mouse.
**Pace:** compress (skip explain, demo only novel steps) when the last 2 tasks were first-attempt successes and all prereqs ≥0.85; expand (insert remediation branch) whenever a rubric criterion tagged to a prerequisite fails. `pace` multiplies time-boxes and narration density.
**Depth:** every explain segment ships `core` and `deep` variants; serve `deep` when the learner asks "why" twice in a unit or goal is professional.
**Language:** mirror observed `cs_ratio` ±10 points; tool vocabulary stays English (FCP's UI is English — "Blade tool" said in a Nepali sentence); frustration >0.6 shifts 20 points toward primary language and slows TTS rate 10%.
**Difficulty:** next lesson requires all prereqs ≥0.7; within a lesson, pick easy/standard/stretch task variant — stretch when p>0.8 and confidence >0.6.

**The anti-dependence metric:** assist score per task = Σ weighted help events (L4=4, L3=2, L2=1, L1=0.5). *Assistance-per-task must trend down per skill.* Product-level health: median capstone assist <0.5 and negative slope for ≥80% of active learners. If a learner's slope is flat or rising across 3 sessions, the engine force-caps scaffolding one level lower — the tutor is structurally forbidden from becoming a doing-agent. This is the operational inversion of the task-agent industry, and the direct answer to the Lancet/METR/novice-gap deskilling evidence. **Trade-off:** aggressive fading will occasionally frustrate; we accept short-term friction for transfer, and the frustration signal bounds it. **Constitution:** this metric *is* the concept's inversion made measurable; serves 5, guards against violating the product's reason to exist.

## 6. Authoring economics

**v1 (hand-authored):** a pair — one working FCP editor (domain expert) + one learning engineer who owns the spec format — authors each lesson. Estimate: 20–30 h/lesson early (spec + starter assets + verify predicates + engine replay-test on a clean Mac), falling to ~12–15 h once templates and the asset library mature. Basis: interactive-elearning industry norms of ~50–150 dev-hours per finished hour, discounted because the spec is templated and assets are shared across a unit — this is an estimate, not a measurement. Full 21-lesson course ≈ 350–550 hours ≈ one pair, one quarter. That cost is acceptable exactly once — which is why v2 exists.

**v2 (the Lesson Compiler — the content flywheel):** an expert teaches naturally on an instrumented Mac; the pipeline drafts the spec. Stages: (1) **capture**: ScreenCaptureKit video + AXObserver event log + keystroke tap + mic; (2) **align**: ASR transcript time-locked to AX events; (3) **segment**: classify spans into explain vs demonstrate moves; (4) **lift**: AX event runs → semantic intents, with verify predicates auto-generated from before/after AX and FCPXML diffs (the diff *is* the checkpoint); (5) **draft**: LLM writes narration beats, Board IR from the spoken explanation, rubric from the expert's own end state, hint ladder from their asides; (6) **review**: human edits in a spec-review UI, then a mandatory engine replay test on a clean VM. Target: 3–6 h human review per lesson (estimate) — a 4–6x cost reduction — and every real tutoring session feeds the error-pattern library that powers `remediate` blocks. **Trade-off:** the compiler is a real engineering project (roughly a quarter for two engineers, estimate); building it before v1 lessons prove the spec format would be premature — v1's hand-authoring is also the requirements discovery for v2.

**v3 (marketplace endgame, one paragraph):** experts record courses through the compiler and publish Lesson Specs that *execute as live tutors* on any learner's machine — Substack-for-skills where the course teaches you itself, watches you practice, and grades what it watched. The replay test is the listing quality gate; revenue-shares with authors; the platform keeps the compounding assets no author can replicate alone — the cross-course error-pattern library, the executor libraries per app, and longitudinal learner models. Because the spec is model-portable, marketplace content survives every engine upgrade, making the catalog, not the model, the durable moat.