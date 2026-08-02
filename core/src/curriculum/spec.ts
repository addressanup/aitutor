import { parse as parseYaml } from "yaml";
import { z } from "zod";

/**
 * Lesson Spec v0 (docs/execution-plan.md §3.6 + Appendix A). Declarative, semver'd,
 * app-AGNOSTIC: actions are semantic intents resolved by a per-app executor at
 * runtime; verify predicates are machine-checkable. No app name is hard-coded
 * anywhere — the domain is open (any teachable software). Model-portable: swapping
 * the engine's model changes execution reliability only, never this content.
 */

const DepthText = z.object({ core: z.string(), deep: z.string().optional() });

const BoardOp = z.object({ op: z.string() }).loose();

const CheckOp = z.object({ op: z.string() }).loose();

const ExplainSegment = z.object({
  id: z.string(),
  say: DepthText,
  board: z.array(BoardOp).optional(),
  check: z.array(CheckOp).optional(),
});

const DemoStep = z.object({
  id: z.string(),
  intent: z.string(),
  channels: z.array(z.enum(["ax", "keys", "vision"])).optional(),
  pre: z.record(z.string(), z.unknown()).optional(),
  narrate: z.string().optional(),
  verify: z.record(z.string(), z.unknown()),
});

const Practice = z.object({
  starter_assets: z.record(z.string(), z.unknown()).optional(),
  task: z.string(),
  time_box_min: z.number().positive().optional(),
});

const RubricCriterion = z
  .object({
    crit: z.string(),
    detect: z.string(),
    weight: z.number().min(0).max(1),
    when: z.string().optional(),
  })
  .loose();

const Hint = z.object({ level: z.enum(["L0", "L1", "L2", "L3", "L4"]) }).loose();

const Remediation = z.object({ on: z.string() }).loose();

const ReviewItem = z.object({ due_days: z.array(z.number()), task: z.string(), pass: z.string() });

export const LessonSpec = z.object({
  lesson: z.string(),
  version: z.string().regex(/^\d+\.\d+\.\d+$/, "lesson version must be semver"),
  /** The app this lesson targets, as data — never special-cased in engine code. */
  app: z.object({ bundleId: z.string(), name: z.string().optional() }),
  skills: z.object({
    teaches: z.array(z.string()).min(1),
    requires: z.array(z.string()).default([]),
  }),
  explain: z.array(ExplainSegment).default([]),
  demo: z.array(DemoStep).default([]),
  practice: Practice,
  rubric: z.array(RubricCriterion).default([]),
  hints: z.array(Hint).default([]),
  remediate: z.array(Remediation).default([]),
  review: z.array(ReviewItem).default([]),
});
export type LessonSpec = z.infer<typeof LessonSpec>;

export function parseLessonSpec(yamlText: string): LessonSpec {
  return LessonSpec.parse(parseYaml(yamlText));
}
