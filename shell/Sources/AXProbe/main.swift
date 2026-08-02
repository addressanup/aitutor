import AXBridge
import AppKit
import ArgumentParser
import Foundation
import os

/// Thread-safe counter so the collector Task never captures a mutating local.
final class NoteCounter: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [String: Int]())
    func bump(_ key: String) { state.withLock { $0[key, default: 0] += 1 } }
    func snapshot() -> [String: Int] { state.withLock { $0 } }
}

// AXObserver density probe (execution-plan §7 spike a). App-GENERIC: point it at
// any bundle id and drive the app by hand; it logs each notification and prints a
// per-notification count table + events/sec. The data that decides whether the
// hit-testing fallback is needed for a given app's canvas.
@main
struct AXProbe: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "axprobe",
        abstract: "Log AXObserver notification density for a target app while you drive it by hand."
    )

    @Option(name: .long, help: "Bundle id of the app to observe, e.g. com.apple.TextEdit")
    var bundleId: String

    @Option(name: .long, help: "How long to observe, in seconds.")
    var seconds: Int = 60

    @Flag(name: .long, help: "Print every event as it arrives.")
    var verbose = false

    mutating func run() async throws {
        guard AXIsProcessTrusted() else {
            FileHandle.standardError.write(Data("Accessibility not granted to this terminal. Grant it in System Settings → Privacy & Security → Accessibility, then retry.\n".utf8))
            throw ExitCode.failure
        }
        guard let pid = AXElement.pid(forBundleId: bundleId) else {
            FileHandle.standardError.write(Data("App not running: \(bundleId)\n".utf8))
            throw ExitCode.failure
        }

        let stream = AXObserverStream(pid: pid)
        guard stream.start() else {
            FileHandle.standardError.write(Data("Could not create AXObserver (permission or pid issue).\n".utf8))
            throw ExitCode.failure
        }

        print("Observing \(bundleId) (pid \(pid)) for \(seconds)s — drive the app now…\n")
        let counter = NoteCounter()
        let isVerbose = verbose
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))

        let events = stream.events
        let collector = Task {
            for await ev in events {
                counter.bump(ev.notification)
                if isVerbose {
                    print("  \(ev.notification)  role=\(ev.role ?? "-") title=\(ev.title ?? "-")")
                }
            }
        }

        while Date() < deadline { try await Task.sleep(for: .milliseconds(200)) }
        stream.stop()
        collector.cancel()

        let counts = counter.snapshot()
        print("\n— notification counts —")
        let total = counts.values.reduce(0, +)
        for (note, count) in counts.sorted(by: { $0.value > $1.value }) {
            print("  \(note.padding(toLength: 40, withPad: " ", startingAt: 0)) \(count)")
        }
        print("\n  total: \(total)   rate: \(String(format: "%.2f", Double(total) / Double(seconds))) events/sec")
    }
}
