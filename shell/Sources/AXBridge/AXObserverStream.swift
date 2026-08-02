@preconcurrency import ApplicationServices
import Foundation

// The canonical C-callback → Swift concurrency bridge. An AXObserver's callback
// is a C function pointer; its refcon is an Unmanaged pointer to a Box that holds
// only an AsyncStream.Continuation (Sendable by design). The callback converts CF
// types to a Sendable value struct and yields — nothing else. This is the ONLY
// sanctioned pattern for AX (and, later, CGEventTap) callbacks under Swift 6.

public struct AXEvent: Sendable {
    public let notification: String
    public let role: String?
    public let title: String?
    public let atMs: Int64
}

/// Notifications relevant to observing a learner's actions (execution-plan §3.3).
public let kDefaultAXNotifications: [String] = [
    kAXValueChangedNotification,
    kAXFocusedUIElementChangedNotification,
    kAXSelectedTextChangedNotification,
    kAXMenuOpenedNotification,
    kAXMenuItemSelectedNotification,
    kAXWindowCreatedNotification,
    kAXWindowMovedNotification,
    kAXWindowResizedNotification,
    kAXTitleChangedNotification,
    kAXUIElementDestroyedNotification,
    kAXApplicationActivatedNotification,
]

// SAFETY: the Box is touched only by the C callback (single-threaded on the
// observer's run-loop thread) and holds a Sendable continuation.
private final class ContinuationBox: @unchecked Sendable {
    let continuation: AsyncStream<AXEvent>.Continuation
    init(_ c: AsyncStream<AXEvent>.Continuation) { self.continuation = c }
}

private func axCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let box = Unmanaged<ContinuationBox>.fromOpaque(refcon).takeUnretainedValue()
    let el = AXElement(element)
    let ms = Int64(Date().timeIntervalSince1970 * 1000)
    box.continuation.yield(
        AXEvent(notification: notification as String, role: el.role, title: el.title, atMs: ms)
    )
}

/// Attaches an AXObserver on a dedicated run-loop thread and exposes its
/// notifications as an AsyncStream. Powers axprobe.
public final class AXObserverStream: @unchecked Sendable {
    private let thread: RunLoopThread
    private let pid: pid_t
    private var observer: AXObserver?
    private var box: ContinuationBox?

    public let events: AsyncStream<AXEvent>
    private let continuation: AsyncStream<AXEvent>.Continuation

    public init(pid: pid_t, threadName: String = "ax-observer") {
        self.pid = pid
        self.thread = RunLoopThread(name: threadName)
        var cont: AsyncStream<AXEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Register the given notifications on the app element. Returns false if the
    /// observer can't be created (usually missing Accessibility permission).
    @discardableResult
    public func start(notifications: [String] = kDefaultAXNotifications) -> Bool {
        var obs: AXObserver?
        guard AXObserverCreate(pid, axCallback, &obs) == .success, let observer = obs else {
            return false
        }
        self.observer = observer
        let box = ContinuationBox(continuation)
        self.box = box
        let refcon = Unmanaged.passUnretained(box).toOpaque()
        let appElement = AXUIElementCreateApplication(pid)

        for note in notifications {
            AXObserverAddNotification(observer, appElement, note as CFString, refcon)
        }
        let source = AXObserverGetRunLoopSource(observer)
        thread.perform {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        return true
    }

    public func stop() {
        continuation.finish()
        if let observer {
            let source = AXObserverGetRunLoopSource(observer)
            thread.perform {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            }
        }
    }
}
