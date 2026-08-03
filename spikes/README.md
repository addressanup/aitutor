# spikes

Throwaway-by-contract experiments that answer a single question, then die (their
findings live in `docs/notes/`, not their code). The two M0 week-1 de-risking
spikes (docs/execution-plan.md §7) are implemented as **permanent diagnostic
executables** in the Swift shell rather than here, because they reuse `AXBridge`:

- **AXObserver notification density** — `make spike-ax TARGET=<bundleId>`
  (shell target `AXProbe`). Answers: does the target app emit enough AX
  notifications to run the ~$0 semantic observation layer, or is the
  click-hit-testing fallback needed?
- **Snapshot ritual** — `make spike-snapshot TARGET=<bundleId> MENU="File>Export…"`
  (shell target `SnapshotSpike`). Answers: can the announced export-XML ritual be
  driven via AX menus and restore focus inside the 2–4 s budget?

A third executable, `axdrive`, performs the actions so both protocols run without a
human at the keyboard. The acceptance protocols are `make spike-ax-run` and
`make spike-snapshot-run`; those are what produce the committed results and what a
second machine runs to replicate.

**Both spikes measure a completion, not a dispatch.** The ritual counts a run only
when the exported artifact lands on disk and focus returns to the app, and density
verdicts are computed from the run's own logs by
`shell/Scripts/ax-density-verdict.mjs`. Both rules exist because an earlier version
of the ritual counted a menu press as success and reported a poll timeout as its
p95 — 50 runs, 0 failures, and not one completed export. When a spike says a bar is
met, the evidence has to be recomputable by someone who does not trust it.

New single-question spikes that do NOT reuse shell organs get their own folder
here (e.g. `spikes/03-figma-bridge/`), with a one-paragraph README stating the
question and where the answer was written down.
