import CoreGraphics
import Foundation

// The listen-only tap is NOT started at scaffold — this defines the API and the
// synthetic-vs-hardware discrimination contract it will use, and hosts the single
// synthetic-input choke point (SyntheticKeyPoster) so no system-wide post call
// site can ever exist.

/// A magic user-data tag stamped on every synthetic event we post, so the listen
/// tap can distinguish our events (CGEventSourceStateID == our private source,
/// userData == this tag) from genuine hardware input within microseconds.
public let kTutorSyntheticTag: Int64 = 0x5455_544F_5200_0001  // "TUTOR\0\0\1"

public enum InterruptKind: String, Sendable {
    case keyboard, mouse
    case doubleEsc = "double_esc"
}

/// Stub for the listen-only CGEventTap (execution-plan §3.2). The real implementation
/// creates a tap at kCGHIDEventTap with kCGEventTapOptionListenOnly on a dedicated
/// CFRunLoop thread, classifies each event by kCGEventSourceStateID + the userData
/// tag, and calls `onLearnerInput` for genuine hardware input — which flips the
/// possession gate to the learner synchronously.
public final class EventTapGuard: @unchecked Sendable {
    private let gate: PossessionGate

    public init(gate: PossessionGate) {
        self.gate = gate
    }

    /// Not started at scaffold. Documented so the concurrency + threading model is fixed.
    public func start(onLearnerInput: @escaping @Sendable (InterruptKind) -> Void) {
        _ = onLearnerInput
        // Future: RunLoopThread + CGEvent.tapCreate(.cgSessionEventTap, .listenOnly, ...)
        // classify via CGEventGetIntegerValueField(event, .eventSourceStateID) and
        // CGEventGetIntegerValueField(event, .eventSourceUserData) != kTutorSyntheticTag.
    }

    public func stop() {}
}
