# research:landscape-pedagogy

## key_facts
- No shipped product as of Aug 2026 combines computer-use demonstration + learner observation + skill teaching; closest gaps: Copilot Vision guides but never demonstrates or assesses; Screen Copilot (screencopilot.app) watches and guides ($12-120/mo) but cannot control the mouse; Adobe's Creative Agent does the work instead of teaching it.
- Khanmigo (Khan Academy): $4/mo or $44/yr for learners, free for US K-12 teachers, still text-chat academic tutoring only, no screen awareness (khanmigo.ai, kidsaitools reviews, May 2026).
- Synthesis Tutor: ~$29/mo or ~$119/yr, ages 5-11 math only, no software teaching (brighterly.com, 2026).
- ChatGPT Study Mode (Jul 29 2025), Gemini Guided Learning on LearnLM (Aug 6 2025), Claude Learning Mode to all users (Aug 14 2025) - all three labs shipped Socratic chat modes; none see the learner's screen or software.
- Microsoft Copilot Vision with Highlights (US rollout Jun 12 2025, free in Windows/M365): shares an app window, answers 'show me how' by highlighting where to click - guidance, not demonstration, no learner assessment, Microsoft-ecosystem-centric.
- Gemini Live screen-share (free in Gemini app) can watch a shared screen and coach in real time but cannot control the machine, demonstrate, or run a curriculum.
- Cluely: $20/mo Pro, $75-150/mo with undetectable overlay - feeds users answers during meetings/interviews; anti-learning by design (finalroundai/interviewcoder pricing reviews 2026).
- Highlight AI: free desktop screen-aware assistant (Mac/Windows), pivoting to Teams product; memory/recall and meeting notes, not teaching (highlightai.com, 2026).
- Adobe AI Assistant public beta Jun 18 2026 across Premiere/Photoshop/Illustrator/InDesign/Frame.io: executes multi-step workflows from described outcomes - a task agent inside the tool, explicitly doing rather than teaching (news.adobe.com).
- SAMMY Labs (YC W25): AI navigates a vendor's app like a user to auto-generate walkthroughs/onboarding content; priced per update/action (~$0.03-0.30); serves the vendor's customer-success org, not the learner's skill (ycombinator.com/launches).
- Digital adoption incumbents: Scribe from $23/user/mo; iorad $200/mo individual, $500/mo team; WalkMe custom enterprise pricing only (SAP-owned; AI features move to consumption-based SAP AI Units Jan 2027) - all guide clicks in-flow, none build transferable skill (vendr, userpilot, guidde, 2026).
- Human 1:1 benchmark: Wyzant average $35-60/hr (range $10-1000); Preply avg $10-15/hr (langs) to $40+; Superprof $30-100/hr plus $39-49/mo student pass; specialist FCP/Premiere/Excel tutors typically $40-100/hr (estimate from Wyzant averages plus specialist premium).
- Course comps: Ripple Training FCP Core Training $79 one-time; School of Motion All-Access $499/quarter (courses ~$800-1000); MasterClass $120-240/yr; Coursera Plus $59/mo or $399/yr; Skillshare ~$168/yr.
- Free MOOC completion runs 3-15% (3.13% MITx/HarvardX 2017-18, Reich & Ruiperez-Valiente); paid certificates ~48-55%; employer-sponsored ~72% - self-paced content demonstrably fails to finish learners.
- Bloom (1984) 2-sigma: 1:1 tutored students ~2 SD above classroom - real but never replicated at that size; modern tutoring meta-analysis (Nickow, Oreopoulos & Quan, AERJ 2024, 96 RCTs) finds pooled 0.37 SD, still among the largest known education effects.
- VanLehn 2011 (Educational Psychologist): intelligent tutoring systems d~0.76 vs human tutoring d~0.79 - step-based computer tutors nearly match humans; interaction granularity is the active ingredient.
- Harvard AI-tutor RCT (Kestin et al., Scientific Reports 2025, n=194): custom GPT-4 tutor with research-based pedagogy beat in-class active learning - students learned more than 2x in less time, engagement doubled; design (brevity, scaffolding, cognitive-load management) drove the result, not the raw model.
- World Bank Nigeria RCT (2024-25): 6 weeks of after-school GPT-4/Copilot English tutoring produced 0.23-0.31 SD gains ~ 1.5-2 years of business-as-usual schooling; among top ~20% of rigorously evaluated education programs.
- Lancet Gastroenterology & Hepatology (Aug 2025, Budzyn et al.): after routine AI-assisted colonoscopy, 19 experienced endoscopists' unassisted adenoma detection fell 28.4%->22.4% (6pp absolute, ~20% relative) - first real-world automation deskilling linked to patient outcomes.
- Microsoft + CMU CHI 2025 (Lee et al., 319 knowledge workers, 936 use cases): higher confidence in GenAI correlates with less self-reported critical thinking; effort shifts from doing to verifying/stewardship; cognitive offloading documented.
- METR RCT (Jul 2025, 16 experienced OSS devs, 246 tasks): AI-allowed tasks took 19% LONGER, yet devs believed AI made them 20% faster - perception of AI benefit is unreliable; METR's Feb 2026 update labels the result historical as tools evolve.
- Novice-programmer evidence 2024-25: benefits of GenAI are unevenly distributed - strong metacognition gains, weak metacognition harmed ('widening gap', arXiv 2405.17739); least-experienced users accept the most suggestions including incorrect code; meta-analysis of 35 studies finds performance gains but no significant gain in understanding (MDPI Computers 2025).
- Learning-science anchors: cognitive apprenticeship modeling->coaching->scaffolding->fading (Collins, Brown & Newman 1989) maps 1:1 onto explain->demonstrate->attempt->observe->fade; deliberate practice with immediate feedback at edge of ability (Ericsson et al. 1993); retrieval practice beats re-study (Roediger & Karpicke 2006); Mayer's segmenting + modality principles (spoken narration over on-screen action, learner-paced chunks) are exactly the demonstration format.
- Price corridor implied: above $13-33/mo content subscriptions (Skillshare/Coursera), far below $40-100/hr human tutors; a $30-100/mo tutor that actually completes learners has a wide open band with hard anchors on both sides.

## full_markdown

# Market landscape, benchmarks, and why-now evidence (verified Aug 2026)

## 1. Competitive landscape: nobody ships the full teaching loop

**Direct answer: no shipped product combines (a) computer-use demonstration on the learner's machine, (b) observation of the learner's own attempts, and (c) skill-building intent.** Everything found does at most one of the three.

**AI tutor products (academic, no screen):**
- **Khanmigo** — $4/mo / $44/yr learners, free for K-12 teachers; Socratic chat tutoring on Khan content; no screen awareness, no software domains (khanmigo.ai; reviews, May 2026).
- **Synthesis Tutor** — ~$29/mo or ~$119/yr; adaptive voice-guided math, ages 5-11 (brighterly.com, 2026).
- **Big-lab study modes** — ChatGPT Study Mode (Jul 29, 2025), Gemini Guided Learning on LearnLM (Aug 6, 2025), Claude Learning Mode GA (Aug 14, 2025). All Socratic text chat; none see software, none observe practice. They validate demand for "teach, don't answer" at frontier labs — and simultaneously prove the labs are attacking it screen-blind.

**Screen-watching assistants (see but don't teach):**
- **Microsoft Copilot Vision + Highlights** — free in Windows/M365 (US rollout Jun 12, 2025). "Show me how" highlights where to click inside shared apps. Closest big-tech adjacency: it's guidance-in-the-moment for task completion, Microsoft-app-centric, never demonstrates by acting, never observes/assesses the learner, no curriculum, no memory of skill growth.
- **Gemini Live screen-share** — free; real-time coaching over a shared screen; cannot act on the machine, no structured pedagogy.
- **Screen Copilot** (screencopilot.app) — browser tool marketing exactly "master Excel, learn any software" via Gemini vision watching your screen; $12/$30/$120 per month by daily minutes. Guidance-only, no mouse control, no demonstration, no assessment. Proof the wedge is being probed at the low end.
- **Highlight AI** — free screen-aware desktop assistant, pivoting to Teams; memory/recall, not teaching. **Cluely** — $20/mo (Pro) to $75-150/mo (undetectable overlay); feeds users answers in real time during meetings/interviews — the anti-tutor: it substitutes for skill rather than building it. Its traction is evidence people will pay monthly for a screen-aware overlay.

**In-app AI inside the tools:**
- **Adobe AI Assistant** — public beta Jun 18, 2026 across Premiere, Photoshop, Illustrator, InDesign, Frame.io (After Effects private beta): describes-outcome → executes multi-step workflow (organizes bins, rough cuts). Explicitly a doing agent; every marketing line is "save time," none is "learn the craft" (news.adobe.com, Jun 2026). Figma AI and Excel Copilot are the same shape: generate/do, plus Copilot Vision-style pointing in Microsoft's case.

**Computer-use agents pointed at training/onboarding:**
- **SAMMY Labs (YC W25)** — AI navigates a vendor's app like a user to auto-generate walkthroughs, onboarding, training content; ~$0.03-0.30 per update/action. Sold to the vendor's customer-success team; the "learner" is a user being walked through the vendor's own product. W25/S25 batches are dense with computer-use agents (Zomma etc.) — all pointed at doing work, none found pointed at teaching the human. Nothing matching the tutor concept surfaced on Product Hunt 2025-26 either.

**Digital adoption incumbents (closest adjacency):**
- **Scribe** from $23/user/mo (auto-generated step guides); **iorad** $200/mo individual, $500/mo team (interactive tutorials); **WalkMe** enterprise custom pricing only, SAP-owned, moving AI features to consumption-based SAP AI Units in Jan 2027. All guide clicks inside one vendor-instrumented app for task completion. None demonstrate, observe free practice, or assess skill; all are B2B, sold to the software owner, not the learner.

**Structural takeaway:** every adjacent player is captured by its business model — labs sell task completion, Adobe sells its own software's output, DAP vendors sell to app owners, Cluely sells cheating. The learner-owned, cross-app, skill-building position is empty.

## 2. Human benchmark and price anchors

**1:1 tutoring (the price ceiling):** Wyzant averages $35-60/hr, range $10-1000/hr, +9% student service fee; Superprof $30-100/hr plus a $39-49/mo student pass; Preply averages $10-15/hr for languages, $40+ for specialists. Specialist FCP/Premiere/Excel tutors realistically $40-100/hr (estimate: Wyzant average plus observed specialist premium; Wyzant's FCP listing page confirms dozens of dedicated FCP tutors exist — a real, monetized market).

**Courses (the price floor):** Ripple Training FCP Core $79 one-time; School of Motion All-Access $499/quarter, flagship courses ~$800-1000; MasterClass $120-240/yr; Coursera Plus $59/mo / $399/yr; Skillshare ~$168/yr. **The empty corridor: ~$30-150/mo for something with tutoring-grade outcomes.**

**Outcomes evidence:**
- Free MOOC completion: 3-15%; MITx/HarvardX hit 3.13% in 2017-18 (Reich & Ruiperez-Valiente). Paid certificates ~48-55%; employer-sponsored ~72%. Content without a tutor mostly doesn't finish people.
- Bloom (1984) 2-sigma: tutored students ~2 SD above classroom. Standard caveats: small studies, mastery-learning confound, never replicated at 2σ; the honest modern number is Nickow/Oreopoulos/Quan (AERJ 2024, 96 RCTs): pooled **+0.37 SD** — still among the largest robust effects in education.
- VanLehn (2011): intelligent tutoring systems d≈0.76 vs human tutors d≈0.79 — machine tutors nearly match humans when interaction is fine-grained (step-level, not answer-level). Directly licenses the observe-every-step design.
- Harvard physics RCT (Kestin et al., Scientific Reports 2025, n=194): pedagogy-engineered GPT-4 tutor > in-class active learning; >2x learning in less time, engagement doubled. Active ingredient was instructional design (brevity, scaffolding, cognitive-load control), not model horsepower.
- World Bank Nigeria RCT (2025): six weeks of GPT-4-based after-school tutoring → 0.23-0.31 SD, ≈1.5-2 years of schooling equivalent; top ~20% of rigorously evaluated education interventions ever.

## 3. Why-now evidence file: AI reliance erodes skill

- **Lancet Gastro & Hep, Aug 2025 (Budzyn et al.)**: after months of AI-assisted colonoscopy, 19 experienced endoscopists' *unassisted* adenoma detection fell 28.4%→22.4% (−6pp absolute, ~20% relative). First real-world automation-deskilling result tied to patient outcomes.
- **Microsoft + CMU, CHI 2025 (Lee et al.)**: 319 knowledge workers, 936 GenAI use cases — higher confidence in AI ⇒ less critical thinking; effort shifts from doing to verifying; self-reported cognitive offloading. (Caveat: self-report survey.)
- **METR RCT, Jul 2025**: 16 experienced OSS devs, 246 real tasks — AI-allowed tasks 19% slower, while devs believed 20% faster. Key lesson: perceived AI benefit is unreliable; assessment must come from observed performance. (METR's Feb 2026 update flags the result as historical as tools improve.)
- **Novice programmers, 2024-25**: "widening gap" (arXiv 2405.17739) — GenAI helps students with strong metacognition, harms those without; least-experienced users accept the most (often wrong) suggestions; 35-study meta-analysis (MDPI Computers 2025) finds task-performance gains but no significant gain in understanding.

**Learning-science anchors to build on (one line each):**
- **Cognitive apprenticeship** (Collins, Brown & Newman 1989): modeling → coaching → scaffolding → fading — the exact skeleton of explain → demonstrate → attempt → observe → withdraw support.
- **Deliberate practice** (Ericsson, Krampe & Tesch-Römer 1993): improvement requires tasks at the edge of ability with immediate, specific feedback — impossible without observation.
- **Retrieval practice / testing effect** (Roediger & Karpicke 2006): having the learner do it beats re-watching; hand-over must dominate demonstration time.
- **Mayer's multimedia principles**: segmenting (learner-paced chunks) and modality (spoken narration over visual action beats on-screen text) — a narrated live demo on the learner's screen is the textbook-optimal format.

## Positioning implications

- **Position against the entire agent industry's direction of travel**: every funded computer-use agent (Adobe, Operator, Mariner, YC cohorts) does work for you; the deskilling file (Lancet, MSFT/CMU, novice-dev studies) is the marketing narrative — "everyone else's agent makes you weaker; this one makes you stronger."
- **The moat is the loop, not the screen-watching**: Copilot Vision, Gemini Live, and Screen Copilot already watch and point for free/cheap; defensibility lives in demonstration-by-acting + observation-based assessment + longitudinal skill memory, which none of them have and which their business models (sell the doing) resist copying.
- **Price into the empty corridor**: content subs top out ~$33/mo, human specialists start ~$40/hr; a $30-100/mo tier undercuts one hour of human tutoring per month while promising tutoring-class outcomes (0.37 SD honest anchor; Harvard/Nigeria RCTs as AI-specific proof).
- **Claim assessment honesty as a feature backed by METR**: self-perceived progress is provably unreliable (−19% actual vs +20% perceived); \"we grade you on what we watched you do, not what you feel\" is a differentiator no chat-mode tutor can make.
- **Lead with pedagogy engineering, not model access**: Harvard's result came from instructional design on a commodity model; encode cognitive apprenticeship + deliberate practice + segmenting/modality into the session engine and cite the science by name — the labs' study modes prove the demand but are structurally screen-blind, and the incumbents' DAP tools are vendor-owned; the learner-owned cross-app tutor slot is empty as of Aug 2026.