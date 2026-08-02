import CoreGraphics
import Foundation

// The SINGLE choke point for synthetic input. `pid` is REQUIRED so a system-wide
// post call site can never exist (execution-plan §3.2, the check-then-post race).
// At scaffold, posting is a stubbed dry-run guarded by the possession lease — no
// event is ever posted. The tag machinery IS real so the interrupt tap can be
// built against it.

public enum PostError: Error {
    case possessionNotHeld
    case scaffoldDryRun(pid: pid_t, description: String)
}

public struct SyntheticKeyPoster {
    private let gate: PossessionGate

    public init(gate: PossessionGate) {
        self.gate = gate
    }

    /// Post a tagged key event to a SPECIFIC process. At scaffold this validates the
    /// lease and throws `scaffoldDryRun` instead of posting — real posting (via
    /// CGEventPostToPid with the synthetic source + userData tag) lands with the
    /// event-tap work.
    public func postKey(pid: pid_t, keyCode: CGKeyCode, leaseToken: UInt64, dryRun: Bool = true) throws {
        guard gate.holdsLease(leaseToken) else { throw PostError.possessionNotHeld }
        if dryRun {
            throw PostError.scaffoldDryRun(pid: pid, description: "would post keyCode \(keyCode) to pid \(pid) with tag \(kTutorSyntheticTag)")
        }
        // Future (real path, one place only):
        //   let src = CGEventSource(stateID: .privateState)
        //   let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        //   down?.setIntegerValueField(.eventSourceUserData, value: kTutorSyntheticTag)
        //   down?.postToPid(pid)   // never CGEventPost (system-wide)
    }
}
