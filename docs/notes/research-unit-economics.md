# research:unit-economics

## key_facts
- Anthropic API pricing (verified 2026-08: skill cache 2026-06-24 + live docs): Claude Opus 5 (flagship) $5/$25 per MTok in/out; Claude Sonnet 5 (mid) $3/$15 sticker with intro $2/$10 through 2026-08-31; Claude Haiku 4.5 (small) $1/$5. Fable 5 super-flagship exists at $10/$50 but is overkill for tutoring.
- Prompt caching: cache reads ~0.1x input price, writes 1.25x (5-min TTL) or 2x (1-hr TTL); minimum cacheable prefix 512 tokens on Opus 5, 1024 on Sonnet 5. Batch API 50% off but unusable for realtime.
- Vision cost formula (platform.claude.com/docs vision, fetched 2026-08-02): tokens = ceil(w/28) x ceil(h/28). A 1280x800 screenshot = 46x29 = 1,334 tokens, no downscaling on any tier. Cost per screenshot: $0.0067 (Opus 5), $0.0040 (Sonnet 5), $0.0013 (Haiku 4.5).
- Competitor pricing: OpenAI GPT-5.2 $0.875/$7.00 per MTok (input price halved in past 90 days - pricepertoken.com, Aug 2026); Google Gemini 3.1 Pro $2/$12 (rises $4/$18 above 200K context), Gemini 3.5/3.6 Flash ~$1.50/$7.50-9.
- Architecture A (naive pixel streaming, Opus 5, frame every 2s = 900 frames over 30 practice min): ~$26/session-hour WITH aggressive prompt caching + 20-frame sliding window; ~$150-160/session-hour without caching. Kills flat-rate pricing outright.
- Architecture B (event-driven foveated: 1 frontier look/15s, Haiku pre-screen, Sonnet narration, frontier demo loop of ~90 actions): ~$5.1-6.3/session-hour LLM COGS ($6.3 with Opus-driven demonstration, $5.1 with Sonnet-driven demonstration).
- Architecture C (local model watches continuously at $0 marginal, frontier consulted ~45x at checkpoints, Sonnet-driven demo): ~$3/session-hour LLM COGS.
- Voice COGS: component stack (Deepgram STT ~$0.01/min full-hour listening + Cartesia/ElevenLabs TTS $0.03-0.08/min of speech) = ~$1.3-2.6/hour. OpenAI Realtime gpt-realtime-2.1 measured $0.06-0.11/min = $3.6-6.6/hr (mini $1.2-3/hr). Component stack is the right fit since the observation LLM already exists.
- All-in COGS per tutor-hour (LLM + voice): Architecture B ~ $7-9/hr, Architecture C ~ $4-5/hr. Use B=$8, C=$4.50 for planning.
- Margin table: at $20/mo only C at 4h/mo is positive (+$2). At $30/mo, C is positive at 4h (+$12, 40% margin), roughly breakeven at 8h. At $50/mo: B positive only at 4h (+$18, 36%); C positive at 4h (+$32, 64%) and 8h (+$14, 28%). At 16h/mo EVERY flat price tested loses money under both architectures (B loses $78-108, C loses $22-52).
- Core strategic conclusion: flat unlimited subscription is not viable; the product needs metered tutor-hours (hour caps per tier or per-hour pricing ~$8-15/hr, which still undercuts human tutors 4-8x at 40-70% gross margin).
- WTP anchors: ChatGPT Plus and Claude Pro $20/mo (Claude $17/mo annual); OpenAI Pro tiers $100 and $200/mo prove prosumers pay >$20 for AI. Khanmigo $4/mo ($44/yr, $15/student/yr for districts). MasterClass $120-240/yr (annual only). Skillshare ~$168/yr. Chegg $15.95-19.95/mo. Human tutors $25-80/hr average, $80-110/hr for test-prep/advanced STEM. Corporate training $846-1,420 per employee per year ($3,270 in tech).
- Khanmigo's $4/mo anchor is dangerous because it is a philanthropy-subsidized nonprofit text chatbot whose COGS is cents/user/month; a computer-watching voice tutor burns ~$4-8 per active HOUR - 2-3 orders of magnitude more - so Khanmigo's price is not evidence of viable unit economics for this category.
- Cost tailwind: frontier prices are falling fast (GPT-5.2 input -50% in 90 days; Sonnet 5 intro discount; Opus 5 at half of Fable 5). Assume ~2x/year COGS decline, meaning B economics migrate toward today's C economics within ~12 months.
- Demonstration phase is screenshot-heavy regardless of architecture: ~2 model actions/step x 45 steps = 90 vision calls = ~$2.5 (Opus) or ~$1.3 (Sonnet) per session - it is the irreducible floor under B and C.

## full_markdown

# Unit Economics: Live Computer-Watching Voice Tutor

All prices verified 2026-08-02. Sources: platform.claude.com docs (vision page fetched live; pricing via Anthropic skill cache 2026-06-24), pricepertoken.com/benchlm.ai (OpenAI/Gemini, Aug 2026), HackerNoon/Layer3Labs measured Realtime-API data (Jul 2026), vendor pricing pages via search.

## 1. Model pricing (per MTok, in/out)

| Tier | Model | Input | Output | Notes |
|---|---|---|---|---|
| Flagship | Claude Opus 5 | $5.00 | $25.00 | 1M ctx; the right "frontier" for a tutor. (Fable 5 exists at $10/$50 — unnecessary.) |
| Mid | Claude Sonnet 5 | $3.00 | $15.00 | Intro $2/$10 through 2026-08-31; near-Opus on agentic work |
| Small | Claude Haiku 4.5 | $1.00 | $5.00 | 200K ctx; triage/pre-screening tier |

**Caching:** reads ≈0.1× input price ($0.50/MTok on Opus 5), writes 1.25× (5-min TTL) / 2× (1-hr). Min cacheable prefix: 512 tok (Opus 5), 1024 (Sonnet 5). Batch −50% (not usable live).

**Vision:** tokens = ⌈w/28⌉×⌈h/28⌉. **1280×800 screenshot = 46×29 = 1,334 tokens** (no downscale on any tier). Per screenshot: **$0.0067 Opus 5 / $0.0040 Sonnet 5 / $0.0013 Haiku**.

**Comparators (one line each):** OpenAI GPT-5.2: $0.875/$7 per MTok — input price halved in the last 90 days; materially cheaper than Opus 5 for vision-heavy loops (pricepertoken.com, Aug 2026). Google Gemini 3.1 Pro: $2/$12 (jumps to $4/$18 above 200K ctx); Gemini 3.5/3.6 Flash ~$1.50/$7.50–9; context caching up to −90% (cloudzero/metacto, 2026).

## 2. 60-minute session LLM COGS

Session structure assumed: ~10 min explain (dialog) + ~15 min demonstrate (agent action loop) + ~30 min learner practice (observation) + ~5 min feedback. Estimates, basis shown; output tokens assumed small during silent observation (~30–50/frame).

### A. Naive pixel streaming (Opus 5 sees a frame every 2s)
- Practice: 30 min × 30 frames/min = **900 frames**. Per call (20-frame sliding window ≈30K cached prefix): cache-read 30K×$0.50/M = $0.015 + cache-write 1.5K×$6.25/M = $0.009 + 30 out×$25/M = $0.001 ≈ **$0.025/call** → 900 × $0.025 = **$22.60**
- Demonstration: 90 actions (45 steps × 2) × $0.028 (adds ~150 output tok/action) = **$2.53**
- Dialog: 40 turns × $0.02 = **$0.80**
- **Total ≈ $26/session-hour** — and that is the *optimistic* case (aggressive caching + sliding window). Truly naive (no caching, growing context): 900 × 31.5K × $5/M ≈ **$150–160/session-hour**. Either number kills consumer pricing; the uncached number exceeds a human tutor.

### B. Event-driven foveated (recommended baseline)
- OS events (mouse/keyboard/window/accessibility) are free signals; Haiku pre-screens ~1 frame/5s: 360 × 1,334 tok × $1/M = **$0.49**
- Frontier looks: 1 frame/15s × 30 min = 120 Opus calls × $0.022 (20K cached prefix read + frame write + 50 out) = **$2.62**
- Routine narration on Sonnet 5: 40 turns × $0.009 = **$0.35**
- Demonstration: 90 actions — Opus-driven **$2.53**, or Sonnet-driven **$1.32**
- Frontier dialog at key teaching moments: 15 × $0.02 = **$0.30**
- **Total ≈ $6.3/session-hour (Opus demo) or $5.1 (Sonnet demo)** → plan on **~$6/hr**

### C. Local-first
- On-device small model (e.g. quantized VLM) watches continuously: **$0 marginal**
- Frontier checkpoints: 1.5/min × 30 min = 45 calls × $0.030 (15K cached read + 3.5K fresh frame+summary + 200 out) = **$1.35**
- Demonstration: Sonnet-driven 90 actions = **$1.32** + 10 Opus spot-checks = $0.30
- Dialog (local/Sonnet mix): **$0.20**
- **Total ≈ $3/session-hour**

Demonstration is the irreducible floor: ~$1.3–2.5/session under every architecture, because real agent action loops need real screenshots.

## 3. Voice COGS per hour
- **Component stack (right fit — the observation LLM already generates the text):** STT full-hour listening: Deepgram ~$0.01/min → $0.60/hr (Cartesia Ink-Whisper as low as $0.13/hr). TTS on ~20–25 min of tutor speech: Cartesia ~$0.03/min → $0.60–0.75/hr; ElevenLabs $0.05–0.08/min → $1.00–2.00/hr. **Total ~$1.3–2.6/hr.**
- **OpenAI Realtime (speech-to-speech alternative):** gpt-realtime-2.1 $32/$64 per M audio tokens (user 600 tok/min, assistant 1,200 tok/min); measured real-world **$0.06–0.11/min = $3.6–6.6/hr** with caching (mini: $1.2–3/hr). (HackerNoon/Layer3Labs, 2026.)

**All-in COGS per tutor-hour (LLM + voice): B ≈ $7–9 (use $8); C ≈ $4–5 (use $4.50).** A ≈ $28–160 — not viable.

## 4. Willingness-to-pay anchors (2026)
- **ChatGPT Plus / Claude Pro: $20/mo** (Claude $17/mo annual). OpenAI Pro tiers at $100 and $200/mo prove prosumers pay well above $20 for AI they rely on.
- **Khanmigo: $4/mo** ($44/yr; $15/student/yr districts). **Dangerous anchor:** it is a nonprofit, philanthropy-subsidized, text-only chatbot whose COGS is cents per user-month. A computer-watching voice tutor burns $4–8 per *active hour* — 2–3 orders of magnitude more. Khanmigo's price signals consumer expectations, not viable economics; do not let it set the price floor.
- **MasterClass: $120–240/yr** (annual-only). **Skillshare: ~$168/yr.** **Chegg: $15.95–19.95/mo.** Prosumer tools (Notion AI, Copilot, Cursor-class) cluster **$20–40/mo**.
- **Human tutors: $25–80/hr average; $27–55/hr online K-12; $80–110/hr test-prep/advanced STEM** (tutors.com, tutorcruncher 2026). This is the real comparator: at $4–8/hr COGS the AI tutor has a **5–20× cost advantage per hour over the cheapest human**.
- **Corporate training: $846 (ATD direct spend) to $1,420/employee/yr average; $3,270 in tech.** One employee's annual budget funds ~100–300 AI tutor-hours at COGS — B2B absorbs these unit costs trivially; consumers at $20/mo do not.

## 5. Monthly gross margin table (LLM+voice COGS only; B=$8/hr, C=$4.50/hr)

| Price / usage | B COGS | B margin (%) | C COGS | C margin (%) |
|---|---|---|---|---|
| $20 · 4 h | $32 | **−$12** (−60%) | $18 | **+$2** (10%) |
| $20 · 8 h | $64 | −$44 | $36 | −$16 |
| $20 · 16 h | $128 | −$108 | $72 | −$52 |
| $30 · 4 h | $32 | −$2 (−7%) | $18 | **+$12** (40%) |
| $30 · 8 h | $64 | −$34 | $36 | −$6 (~breakeven) |
| $30 · 16 h | $128 | −$98 | $72 | −$42 |
| $50 · 4 h | $32 | **+$18** (36%) | $18 | **+$32** (64%) |
| $50 · 8 h | $64 | −$14 | $36 | **+$14** (28%) |
| $50 · 16 h | $128 | −$78 | $72 | −$22 |

## 6. What the math decides
1. **Architecture A is disqualified** ($26–160/hr). Foveated observation is not an optimization, it is the existence condition of the business. Architecture choice = 4–30× COGS lever.
2. **Flat unlimited pricing fails at every tested price** for a 16 h/mo user. Viable structures: (a) **hour-capped tiers** (e.g. $30/mo incl. 4 h, ~40% margin under C), (b) **per-hour metering at ~$8–15/tutor-hour** — 40–70% gross margin while still 4–8× cheaper than a human tutor, or (c) **B2B per-seat** against $846–1,420/employee/yr training budgets.
3. **C is the target architecture, B is the launch architecture.** B works today at $50/4h or metered; token prices are falling ~2×/yr (GPT-5.2 input −50% in 90 days; Sonnet intro pricing), so B's economics become today's C within ~12 months even without local-model work.
4. **Sensitivities:** output tokens during observation (assumed near-silent; a chatty tutor 2–3×'s output cost); cache-hit discipline (a single cache-buster in the loop multiplies COGS ~6×); demo step count; screenshot cadence during practice is the single biggest dial ($0.007/look on Opus — every 15s vs every 2s is the whole game).