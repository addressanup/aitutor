import Foundation

// A dedicated CFRunLoop-owning thread. AXObserver run-loop sources (and later the
// CGEventTap source) attach HERE, never to the main run loop — the sanctioned
// pattern for C callbacks under Swift 6 strict concurrency. Reused by the event tap.

// SAFETY: holds a CFRunLoop set once on the worker thread before `started` is
// signalled, then only read. CoreFoundation types aren't Sendable-annotated.
private final class RunLoopHolder: @unchecked Sendable {
    var loop: CFRunLoop?
}

public final class RunLoopThread: @unchecked Sendable {
    private let thread: Thread
    private let holder = RunLoopHolder()

    public init(name: String) {
        let started = DispatchSemaphore(value: 0)
        let holder = self.holder
        thread = Thread {
            holder.loop = CFRunLoopGetCurrent()
            started.signal()
            let timer = Timer(timeInterval: .greatestFiniteMagnitude, repeats: false) { _ in }
            RunLoop.current.add(timer, forMode: .default)
            CFRunLoopRun()
        }
        thread.name = name
        thread.start()
        started.wait()
    }

    /// Run a block on the thread's run loop (where CF sources are safe to add/remove).
    public func perform(_ block: @escaping @Sendable () -> Void) {
        guard let runLoop = holder.loop else { return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    public func currentRunLoop() -> CFRunLoop? { holder.loop }
}
