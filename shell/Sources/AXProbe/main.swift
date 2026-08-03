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

    @Flag(name: .long, help: "Set AXManualAccessibility before observing — required for browser-backed (Electron/CEF) apps to build an AX tree at all.")
    var enableAx = false

    @Flag(name: .long, help: "Print the app's menu-bar title tree and exit.")
    var dumpMenu = false

    @Flag(name: .long, help: "Print the focused-window subtree and exit.")
    var dumpTree = false

    @Option(name: .long, help: "Max depth for --dump-tree.")
    var depth: Int = 6

    mutating func run() async throws {
        guard AXIsProcessTrusted() else {
            FileHandle.standardError.write(Data("Accessibility not granted to this terminal. Grant it in System Settings → Privacy & Security → Accessibility, then retry.\n".utf8))
            throw ExitCode.failure
        }
        guard let pid = AXElement.pid(forBundleId: bundleId) else {
            FileHandle.standardError.write(Data("App not running: \(bundleId)\n".utf8))
            throw ExitCode.failure
        }

        let app = AXElement.application(pid: pid)
        if enableAx {
            // Chromium/Electron builds its accessibility tree lazily, only once an
            // assistive client asks. Probing without this reports near-silence — a
            // false Silent verdict, not a measurement of the app.
            let ok = app.setValue(true, for: "AXManualAccessibility")
            print("AXManualAccessibility set: \(ok ? "yes" : "no (attribute unsupported — native app, or already on)")")
            try await Task.sleep(for: .seconds(1))
        }

        if dumpMenu {
            dumpMenuBar(app: app)
            return
        }
        if dumpTree {
            dumpFocusedTree(app: app)
            return
        }

        let stream = AXObserverStream(pid: pid)
        guard stream.start() else {
            FileHandle.standardError.write(Data("Could not create AXObserver (permission or pid issue).\n".utf8))
            throw ExitCode.failure
        }

        print("Observing \(bundleId) (pid \(pid)) for \(seconds)s — drive the app now…\n")
        let counter = NoteCounter()
        let isVerbose = verbose
        let start = Date()
        let startMs = Int64(start.timeIntervalSince1970 * 1000)
        let deadline = start.addingTimeInterval(TimeInterval(seconds))

        let events = stream.events
        let collector = Task {
            for await ev in events {
                counter.bump(ev.notification)
                if isVerbose {
                    // Leading relative timestamp: the density verdict tool clusters events
                    // into repetitions by inter-event silence, which needs a time axis.
                    let t = Double(ev.atMs - startMs) / 1000.0
                    print(String(format: "  [%8.3f] %@  role=%@ title=%@",
                                 t, ev.notification, ev.role ?? "-", ev.title ?? "-"))
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

    /// Walk the native menu bar and print every title path. This is how a driver set
    /// gets authored against real menu titles instead of guessed ones.
    private func dumpMenuBar(app: AXElement) {
        guard let bar = app.attribute(kAXMenuBarAttribute).map({ AXElement($0 as! AXUIElement) }) else {
            print("no menu bar (app may be mid-launch, or has no native menu)")
            return
        }
        print("— menu bar —")
        var count = 0
        func walk(_ node: AXElement, path: [String]) {
            for child in node.children() {
                let title = child.title ?? ""
                let here = title.isEmpty ? path : path + [title]
                if !title.isEmpty, child.role == (kAXMenuItemRole as String) {
                    print("  \(here.joined(separator: " > "))")
                    count += 1
                }
                // Descend through AXMenu containers and into submenus.
                walk(child, path: here)
            }
        }
        walk(bar, path: [])
        print("\n  menu items: \(count)")
    }

    /// Print the focused-window subtree. The diagnostic that shows whether a panel is
    /// present in this app's own AX tree — or living in another process entirely.
    private func dumpFocusedTree(app: AXElement) {
        let windows = (app.attribute(kAXWindowsAttribute) as? [AXUIElement])?.map(AXElement.init) ?? []
        print("— windows: \(windows.count) —")
        for (i, win) in windows.enumerated() {
            let frame = win.frame.map { "\(Int($0.width))x\(Int($0.height)) @ \(Int($0.minX)),\(Int($0.minY))" } ?? "-"
            print("  [\(i)] role=\(win.role ?? "-") subrole=\(win.subrole ?? "-") title=\(win.title ?? "-") frame=\(frame)")
        }

        guard let focused = app.focusedWindow else {
            print("\nno focused window")
            return
        }
        print("\n— focused window subtree (depth \(depth)) —")
        var roleCounts: [String: Int] = [:]
        for (d, el) in focused.descendants(maxDepth: depth) {
            let role = el.role ?? "-"
            roleCounts[role, default: 0] += 1
            let title = el.title.map { $0.isEmpty ? "" : " title=\($0)" } ?? ""
            let sub = el.subrole.map { " subrole=\($0)" } ?? ""
            let ident = el.identifier.map { $0.isEmpty ? "" : " id=\($0)" } ?? ""
            let value = el.stringValue.map { $0.isEmpty ? "" : " value=\($0.prefix(40))" } ?? ""
            let acts = el.actions().filter { $0 != "AXShowMenu" }
            let actions = acts.isEmpty ? "" : " actions=[\(acts.joined(separator: ","))]"
            print("  \(String(repeating: "  ", count: d))\(role)\(sub)\(title)\(ident)\(value)\(actions)")
        }
        let total = roleCounts.values.reduce(0, +)
        print("\n— role counts (n=\(total)) —")
        for (role, n) in roleCounts.sorted(by: { $0.value > $1.value }) {
            print("  \(role.padding(toLength: 32, withPad: " ", startingAt: 0)) \(n)")
        }
    }
}
