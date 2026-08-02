import os

// The possession gate. Defined BEFORE the event tap exists so the contract is
// stable from day one. The <=100ms hardware-interrupt budget (execution-plan §3.2)
// forbids `await` in the tap callback, so the gate is a synchronous lock, never
// an actor.

public enum PossessionHolder: String, Sendable {
    case tutor = "TUTOR"
    case learner = "LEARNER"
    case idle = "IDLE"
}

public struct PossessionState: Sendable {
    public var holder: PossessionHolder
    /// Opaque lease token; the executor may post synthetic events only while it holds this.
    public var leaseToken: UInt64
    public init(holder: PossessionHolder = .idle, leaseToken: UInt64 = 0) {
        self.holder = holder
        self.leaseToken = leaseToken
    }
}

/// Shared between the (future) listen-only tap callback and the posting function.
/// Both read/mutate synchronously via the unfair lock.
public final class PossessionGate: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: PossessionState())

    public init() {}

    public func current() -> PossessionState {
        state.withLock { $0 }
    }

    /// Grant a lease to the tutor; returns the new lease token.
    public func grantToTutor() -> UInt64 {
        state.withLock { s in
            s.holder = .tutor
            s.leaseToken &+= 1
            return s.leaseToken
        }
    }

    /// Revoke instantly (hardware interrupt / panic). Learner takes control.
    public func revokeToLearner() {
        state.withLock { s in
            s.holder = .learner
            s.leaseToken &+= 1
        }
    }

    public func release() {
        state.withLock { s in
            s.holder = .idle
            s.leaseToken &+= 1
        }
    }

    /// True only if the tutor still holds exactly this lease — the posting precondition.
    public func holdsLease(_ token: UInt64) -> Bool {
        state.withLock { $0.holder == .tutor && $0.leaseToken == token }
    }
}
