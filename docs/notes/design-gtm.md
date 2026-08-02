# design:gtm

## headline
Launch as the Live AI Tutor for Final Cut Pro on macOS — metered tutor-hours ($49/mo incl. 5h, founding-100 at $39/4h, $12/hr top-ups) sold through the tutor's own recorded teaching sessions as content, with a Nepali-English signature cohort, DaVinci Resolve Studio as fast-follow, and B2B per-seat training deferred until organic multi-seat pull appears.

## key_decisions
- Primary domain: Final Cut Pro on macOS; audience = FCP 90-day-trial users, CapCut/iMovie graduates going pro, and film/media students; fast-follow = DaVinci Resolve Studio; Figma remains the blackboard adapter, a taught domain third at most
- Signature pilot: one Nepali-English mixed-language cohort (~30 learners) on Sarvam Saaras STT + Gemini 3.1 Flash TTS — a differentiator no US competitor will copy
- Category: 'Live AI Tutor' — positioned against the agent zeitgeist: 'Every agent does your work. This one makes you the one who can.' The deskilling evidence file (Lancet, METR, widening-gap) is the narrative ammunition
- Refuse the Khanmigo $4/mo anchor (philanthropy-subsidized text chatbot, cents/user COGS); comp is human 1:1 software tutoring at $40-100/hr — sell live tutor-hours, not chat access
- Pricing: Core $49/mo incl. 5 tutor-hours, Serious $89/mo incl. 10h, top-ups $12/hr, founding-100 at $39/mo incl. 4h locked 12 months; explain/feedback chat unmetered, only live session hours metered; no flat-unlimited tier ever
- Launch on Architecture B (~$8/hr COGS, 10-18% GM at launch prices), migrate to Architecture C (~$4.50/hr, ~50% GM) within ~12 months riding ~2x/yr token deflation
- Churn: accept graduation as the product working — multi-skill roadmap on one subscription, $9/mo alumni mode, refer-a-skill hour credits, milestone gifting; plan honestly for 10-15%/mo mature churn, ~$390 gross LTV, requiring blended CAC <$100
- Channels: demo-as-content YouTube engine (full tutor sessions + shorts of live mistake-catches), FCP.cafe/r/finalcutpro/Discords/film schools, cohort-gated waitlist (20-30/cohort), 100 hand-picked design partners; zero paid acquisition until referral rate and week-4 retention prove the funnel
- B2B per-seat software training second, not first: needs SOC 2 and reliability reps; pull-forward triggers = 10+ organic multi-seat purchases or 3 LOIs >=$10k; SOC 2 groundwork starts month 9 regardless
- Moat: the teaching loop (demonstrate-by-acting + step-level observation + longitudinal skill memory) compounded by the per-app adapter library, error-mined curriculum graphs, and the session-content flywheel — incumbents' business models resist copying all three
- 12-month milestones: 100 design partners live by Oct 2026 with >=80% unassisted session completion; 500 payers/$20k MRR by Feb 2027 incl. Nepali cohort shipped; 4,000 payers/$150-200k MRR, GM >=45%, >=25% signups from referral/graduate content by Aug 2027
- Kill/pivot: <60% unassisted session completion by month 4 -> guided-only pivot; week-4 retention <25% or trial->paid <8% by month 6 -> B2B pull-forward; COGS >$12/hr at month 6 -> reprice/pause; MRR <$20k at month 6 or <$100k at month 12 -> domain pivot (Excel B2B) or shutdown

## full_markdown

# GTM: The Live AI Tutor — market entry + money model

## 1. First domain + audience: Final Cut Pro on macOS. Fast-follow: DaVinci Resolve Studio.

**Decision:** Primary domain is FCP on Mac. Audience, in priority order: (a) FCP **90-day free-trial** users (FCP is $299.99 one-time; edu bundle $199 — apple.com via search, verified 2026-08-02) — everyone in this funnel is either a $300 buyer or on a purchase-decision countdown, so "get good enough in 90 days to justify $300" is a native offer; (b) CapCut/iMovie creators going pro; (c) film/media students. **Signature pilot:** one Nepali-English mixed-language cohort (~30 learners, Kathmandu students + diaspora creators) — feasible today only via cascaded voice (Sarvam Saaras STT has native Nepali + code-mixing at ~$0.35/hr; Gemini 3.1 Flash TTS Nepali is production-validated at ~$0.03/min, 10x cheaper than ElevenLabs — research digest, 2026). A Nepali founder teaching Nepal's editors in their own mixed language is a marketing asset no US competitor will replicate.

Why FCP beats the alternatives on the six weights:
- **WTP:** self-selected by a paid pro app; specialist FCP tutors bill $40-100/hr on Wyzant — a real, monetized comparator market.
- **Copilot exposure:** Adobe's AI Assistant (Jun 2026) covers Premiere/Photoshop; Apple ships no in-app copilot and no macOS agent runtime. FCP is the copilot-free zone among pro NLEs — our tutor faces no in-app incumbent.
- **Adapter feasibility:** AppleScript is minimal, but CommandPost proves FCP's AX tree supports deep control AND observation; a pre-installed command set + CGEvent keystrokes gives deterministic demos; FCPXML v1.13 round-trips project state for assessment. Proven, medium build cost.
- **Demo-ability:** editors live on YouTube; the tutor teaching FCP on camera is natively watchable marketing.
- **Founder authenticity:** the canonical scenario IS this domain.

**Resolve** is fast-follow, not first: external scripting went Studio-only ($295) at 19.1, so the deep adapter only reaches paying Studio owners — which is exactly why it's the right SECOND market (proven payers, same craft so curriculum/marketing reuse, opens Windows later). The free-tier masses are price-sensitive and adapter-poor. **Figma** is already in the product as the blackboard (plugin + localhost WebSocket bridge), so we build that adapter regardless; as a taught domain it faces Figma's own AI and murkier learner WTP — third at most. **Excel** is the B2B domain (Windows-centric, clashes with macOS-first), deferred to §6.

**Trade-off:** Mac-only + one paid app caps early TAM to a niche — r/davinciresolve alone has ~221k members (gummysearch, 2026) vs a much smaller FCP community. We choose small-and-monetizable over large-and-free.
**Constitution:** principles 1 (their real FCP), 4 (Nepali-English cohort as first-class), 6 (Resolve next proves domain-generality is real, not aspirational).

## 2. Positioning + category

**Decision:** Own the category name **"Live AI Tutor."** Positioning line: **"Every AI agent does your work. This one makes you the one who can."** The zeitgeist is the foil: Adobe's assistant, Operator-descendants, and YC's computer-use cohorts all sell the doing; the deskilling evidence file is our narrative ammunition — Lancet Aug 2025 (endoscopists' unassisted detection −20% relative after AI assistance), METR Jul 2025 (devs 19% slower while believing 20% faster), the novice "widening gap" studies. Secondary claim, unique to us: **honest assessment** — "we grade what we watched you do, not what you feel" (METR proves self-report is unreliable; no screen-blind study-mode chatbot can make this claim).

**Khanmigo anchor handling:** refuse the comparison explicitly and preemptively. Khanmigo at $4/mo is a philanthropy-subsidized nonprofit text chatbot with COGS in cents per user-month; our unit is a live tutor-hour on real software burning $4-8/hr in compute (research digest). The correct comp is human 1:1 software tutoring at $40-100/hr: "a human FCP tutor charges $60 an hour and forgets you between sessions; ours is ~$10 an hour and remembers every keystroke." Price integrity comes from selling **hours of live instruction**, a unit whose market price has never been under ~$35 from a human — not "AI chat access," the unit Khanmigo and $20/mo chatbots have commoditized.

**Trade-off:** category creation is expensive; the term stays unknown unless the §5 content engine works, and we must permanently fight free study modes (ChatGPT/Gemini/Claude) with "they can't see your screen, act on it, or watch you try."
**Constitution:** principles 2, 3, 5 are the category's definitional features; the positioning is the constitution verbatim.

## 3. Pricing

**Decision:** subscription with included tutor-hours + metered top-ups. Flat unlimited is disqualified by the margin table (every tested price loses money at 16h/mo under both B and C).

- **Founding 100 (design partners):** $39/mo incl. 4 tutor-hours, locked 12 months. Under B ($8/hr all-in COGS): $32 COGS → +$7 (18% GM). Under C ($4.50/hr): +$21 (54%).
- **Core:** $49/mo incl. 5h. B: $40 → 18% GM; C: $22.50 → 54%.
- **Serious:** $89/mo incl. 10h. B: $80 → 10%; C: $45 → 49%.
- **Top-ups:** $12/tutor-hour (B: 33% GM; C: 62%). Hours roll over one month. Annual = 2 months free.
- **Unmetered:** text/voice Q&A outside live sessions (cheap, Sonnet/Haiku-class) — the meter applies only to the expensive planes: live demonstration + observed practice.

This sits in the verified empty corridor: above content subs (Skillshare ~$168/yr, Coursera Plus $399/yr), 4-8x under human tutors per hour, and priced per the unit that costs us money. Launch on **Architecture B** (event-driven foveated, ~$8/hr), migrate to **C** (local-first watching, ~$4.50/hr) — with token prices falling ~2x/yr (GPT-5.2 input −50% in 90 days; Sonnet 5 intro pricing), B's economics become today's C within ~12 months, so launch GMs of 10-18% are transitional, not structural. Target blended GM ≥45% by Aug 2027.

**Trade-off:** metering fights the "unlimited AI for $20" expectation and creates meter-anxiety mid-lesson; mitigated by unmetered chat and rollover, but some churn from meter friction is priced in.
**Constitution:** principle 7 — a visible meter makes cost and control legible; mildly strains 4 (personal pacing wants long unhurried sessions; the meter taxes them).

## 4. The churn truth

**Decision:** say it plainly — a good tutor graduates its students; FCP competency is a ~3-4 month arc, and we will not engagement-farm. Structural answers:

1. **Multi-skill roadmap on one subscription:** FCP → Motion/color (Resolve) → Figma (thumbnails, brand) → Excel (channel analytics). Graduation from a skill, not from the product.
2. **Alumni mode, $9/mo:** skill memory retained, periodic refresh sessions (~0.5h/mo COGS ≈ $2-4) — retrieval practice (Roediger & Karpicke) is the pedagogical cover; it is also honest margin.
3. **Milestone gifting + refer-a-skill:** graduation triggers "gift a first month"; referrals pay both sides in tutor-hour credits — graduates are the salesforce.
4. **Honest steady state:** model 10-15%/mo mature churn → ~7-10 month mean paid life → LTV ≈ $49 ARPU × 8 ≈ **$390 gross**, ~$150-250 contribution as B→C. Defensible only with blended CAC <$100, i.e., organic-first (§5). The investor LTV story is **completion + expansion**: MOOCs finish 3-15% of learners; we sell finishing, publish completion rates, and expand graduates into the next skill. We explicitly do NOT claim SaaS-style net revenue retention.

**Trade-off:** alumni mode dilutes ARPU; the multi-skill roadmap forces adapter investment ahead of revenue; capping LTV by refusing dependency-farming is a deliberate ceiling.
**Constitution:** principle 5 — churn-as-graduation is assessment honesty applied to the business model; the cognitive-apprenticeship endpoint is fading, including from the product.

## 5. Channels

1. **The demo IS the content:** weekly YouTube series — full recorded sessions of the tutor teaching a real learner FCP on their real Mac (consented), plus shorts of the money moments: the tutor catching a mistake live, the mouse handover, the mixed Nepali-English explanations. The product performing is the ad; marginal content cost ≈ $0. Nepali cohort sessions are their own viral vector in a market with zero such content.
2. **Communities:** r/finalcutpro, FCP.cafe (CommandPost's home — the exact power-user watering hole), editing Discords, film-school programs. Lead with free live skill-assessment sessions, not promotion.
3. **Waitlist mechanics:** application-gated (Mac check, goal, current level, willingness to be recorded); admit in cohorts of 20-30 so demo reliability and observation load stay debuggable; public "next cohort opens" scarcity.
4. **First 100 design partners:** hand-picked across the three segments + the Nepali cohort; $39 locked; weekly feedback calls; named in credits.

**Why NOT paid acquisition:** (a) long-horizon agent reliability is still the open problem (OSWorld 2.0: ~20-55% vs ~85% short-task) — buying strangers into a product that occasionally fumbles a live demo burns cash AND the category's credibility; (b) onboarding crosses two scary TCC prompts (Accessibility, Screen Recording with macOS 15 monthly re-approval) — conversion is unproven, so CAC is unknowable; (c) the LTV math (§4) needs CAC <$100, which paid won't hit before word-of-mouth exists. Revisit paid only after referral rate ≥25% of signups and week-4 retention ≥40% are measured.

**Trade-off:** organic-only means a slow ramp; every §7 growth number depends on the content engine compounding — if it doesn't by month 6, that is itself a signal (see kill criteria).

## 6. B2B second, not first

**Decision:** per-seat team software-training against $846-1,420/employee/yr training budgets ($3,270 in tech) is the obvious second act — one employee's budget buys 100-300 tutor-hours at COGS. It is second because: (a) an agent that records screens and controls machines cannot pass enterprise security review pre-SOC 2; (b) enterprise pulls us to Windows/Excel breadth before the loop is reliable; (c) consumer cohorts are the training ground for reliability and curriculum. **Pull-forward triggers:** ≥10 organic multi-seat purchases on one card, or 3 LOIs ≥$10k, or consumer kill-criteria tripping while B2B inbound converts. SOC 2 groundwork starts month 9 regardless.

**Trade-off:** we concede 6-12 months in the segment with the easiest unit economics, and risk a DAP incumbent (WalkMe under SAP moves to consumption pricing Jan 2027) or a SAMMY-class computer-use startup claiming "AI software trainer" in enterprise first. Accepted: category proof beats channel greed.

## 7. Moat, milestones, kill criteria

**Moat statement:** The moat is the loop, not the screen-watching (Copilot Vision, Gemini Live, Screen Copilot already watch for free/cheap). Defensibility = demonstrate-by-acting + step-level observation + longitudinal skill memory, compounded by three accumulating assets: (a) the **per-app adapter library** (FCP command-set injection + AX observation, Figma plugin bridge, Resolve API) — deterministic control and event-level observation beat pixel agents on cost AND reliability, and are why B/C economics exist at all; (b) **curriculum graphs mined from observed learner errors** — data no screen-blind tutor can collect; (c) the **session-content flywheel** (§5). Structurally, every adjacent player's business model resists copying: labs sell task completion, Adobe sells its own tools' output, DAP vendors sell to app owners, Cluely sells substitution.

**12-month milestones (from Sep 2026):**
- **M2 (Oct):** 100 design partners live; ≥80% of 60-min sessions complete without human rescue; COGS ≤$8/hr verified.
- **M6 (Feb 2027):** 500 payers, $20k MRR, GM ≥25%; week-4 activated retention ≥40%; Nepali cohort shipped; first graduate portfolio reel published.
- **M9 (May):** 1,500 payers, $60k MRR; Resolve Studio beta; COGS ≤$6/hr (B→C migration underway); SOC 2 started.
- **M12 (Aug 2027):** 4,000 payers, $150-200k MRR, blended GM ≥45%; ≥25% of new signups from referrals/graduate content; ≥3 B2B LOIs.

**Kill/pivot criteria (hard numbers):**
1. Unassisted session completion <60% at month 4 after two architecture iterations → pivot to guided-only (no autonomous demo) — a worse product but a shippable one.
2. Week-4 retention <25% or trial→paid <8% at month 6 → audience pivot: trigger B2B pull-forward immediately.
3. COGS >$12/tutor-hour at month 6 (token deflation thesis failed) → reprice to pure metered $15/hr or pause growth.
4. MRR <$20k at month 6 or <$100k at month 12 with the content engine executed → domain pivot (Excel/B2B) or shutdown; do not iterate a fourth consumer quarter on hope.

**Constitution:** criterion 1's fallback (guided-only) sacrifices principle 2 (demonstration first-class) — it is listed as a pivot, never a quiet degradation.