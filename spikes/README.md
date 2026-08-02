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

New single-question spikes that do NOT reuse shell organs get their own folder
here (e.g. `spikes/03-figma-bridge/`), with a one-paragraph README stating the
question and where the answer was written down.
