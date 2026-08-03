import AXBridge
import AppKit
import ArgumentParser
import Foundation

// Snapshot-ritual rehearsal (execution-plan §7 spike b). App-GENERIC: drive an
// export along a menu title path, fill and confirm whatever panel it raises, and
// time the whole ritual against the 2–4 s budget.
//
// The ritual is measured in phases, and success is the two facts that matter to
// the product: the artifact LANDED ON DISK, and focus RETURNED to the app. Panel
// detection is a diagnostic, not a criterion — an app may present a sheet, a
// dialog window, or nothing at all, but only a file on disk proves the export
// happened, and only restored focus proves the learner has their app back.
//
// Two mechanics here are load-bearing and were learned the hard way:
//   1. When a sheet is up, kAXFocusedWindowAttribute returns THE SHEET, not the
//      document window with a sheet child. A probe for "focused window has an
//      AXSheet child" therefore never matches, however long it polls.
//   2. A save panel is rendered by an out-of-process service
//      (com.apple.appkit.xpc.openAndSavePanelService). Keystrokes posted to the
//      target pid never reach it, so it cannot be driven or dismissed by `key`.
//      AX does reach it, because AppKit bridges the panel's tree into the app.
@main
struct SnapshotSpike: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot-spike",
        abstract: "Drive an export ritual via Accessibility and time it against the ritual budget."
    )

    @Option(name: .long, help: "Bundle id of the target app.")
    var bundleId: String

    @Option(name: .long, help: "Menu path, '>'-separated, e.g. \"File>Export as PDF…\"")
    var menuPath: String

    @Option(name: .long, help: "Directory to save the exported artifact into.")
    var saveTo: String = "/tmp/aitutor-spike-out"

    @Option(name: .long, help: "File name to save as. Defaults to a unique name per run.")
    var filename: String?

    @Option(name: .long, help: "Title of the panel's confirm button.")
    var confirmButton: String = "Save"

    enum ConfirmMethod: String, ExpressibleByArgument {
        case ax, click
        case returnKey = "return"
    }

    @Option(name: .long, help: "How to actuate the confirm button: ax | click | return.")
    var confirmMethod: ConfirmMethod = .click

    /// Button titles that answer an overwrite/replace confirmation raised on top of
    /// the save panel. Localise by passing --overwrite-titles if the Mac is not English.
    @Option(name: .long, parsing: .upToNextOption, help: "Button titles that confirm an overwrite.")
    var overwriteTitles: [String] = ["Replace", "Overwrite"]

    @Option(name: .long, help: "How long to wait for the panel, in ms.")
    var panelTimeoutMs: Int = 5000

    @Option(name: .long, help: "How long to wait for the file to land, in ms.")
    var fileTimeoutMs: Int = 8000

    @Option(name: .long, help: "How long to wait for focus to return, in ms.")
    var focusTimeoutMs: Int = 4000

    @Option(name: .long, help: "Upper end of the ritual budget, in seconds.")
    var budgetSeconds: Double = 4.0

    mutating func run() async throws {
        guard AXIsProcessTrusted() else {
            FileHandle.standardError.write(Data("Accessibility not granted to this terminal. Grant it, then retry.\n".utf8))
            throw ExitCode.failure
        }
        guard let pid = AXElement.pid(forBundleId: bundleId) else {
            FileHandle.standardError.write(Data("App not running: \(bundleId)\n".utf8))
            throw ExitCode.failure
        }

        let app = AXElement.application(pid: pid)
        let path = menuPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        let name = filename ?? "snapshot-\(Int(Date().timeIntervalSince1970 * 1000))"
        try? FileManager.default.createDirectory(atPath: saveTo, withIntermediateDirectories: true)
        let targetPath = (saveTo as NSString).appendingPathComponent(name)

        print("Target \(bundleId) (pid \(pid)) — menu path \(path)")
        print("  saving to: \(targetPath)")

        // Activate first, and OUTSIDE the timed window. A learner's app is already
        // frontmost when they export, so activation is setup, not ritual. It is also
        // mandatory: AXPress on a background app's menu item resolves and reports
        // success but never invokes the command — which is how a ritual can look like
        // it fired 50 times while nothing ever happened.
        // Retry: a single activate() often does not take from a CLI tool, which has no
        // main run loop pumping AppKit. Raising the window through AX as well makes it
        // stick where activate() alone silently does not.
        for attempt in 0..<6 where AXElement.focusedApplicationPid() != pid {
            NSRunningApplication(processIdentifier: pid)?.activate(options: [])
            if attempt >= 2 { app.focusedWindow?.perform(kAXRaiseAction as String) }
            _ = await waitFor(timeoutMs: 500) {
                AXElement.focusedApplicationPid() == pid ? true : nil
            }
        }
        guard AXElement.focusedApplicationPid() == pid else {
            FileHandle.standardError.write(Data("Could not bring \(bundleId) frontmost; a menu press would silently do nothing.\n".utf8))
            throw ExitCode.failure
        }

        let t0 = Date()
        func elapsed() -> Double { Date().timeIntervalSince(t0) }
        func fail(_ phase: String, _ detail: String) -> ExitCode {
            print("  ✗ FAILED at \(phase): \(detail)")
            print(String(format: "  phase=%@ total=%.3f", phase, elapsed()))
            dumpDiagnostics(app: app)
            return ExitCode.failure
        }

        // 1 — resolve the menu item
        guard let item = app.menuBarItem(path: path) else {
            throw fail("resolve", "menu item not found along \(path). Is a document open and focused?")
        }
        let tResolve = elapsed()
        print(String(format: "  resolve   %.3fs (title: %@)", tResolve, item.title ?? "-"))

        // 2 — press it
        guard item.press() else { throw fail("press", "AXPress returned failure") }
        let tPress = elapsed()
        print(String(format: "  press     %.3fs", tPress))

        // 3 — race the panel against the artifact.
        //
        // Not every export raises a panel — ⌘S over a located document just writes —
        // and such a ritual finishes long before any panel could appear. Waiting out
        // the panel timeout first would bill that entire wait to a ritual measured
        // against a 2–4 s budget, turning a fast completion into a false overrun.
        let fallbackName = filename ?? app.focusedWindow?.title ?? name
        var earlyArtifact: (path: String, bytes: Int)?
        let panelOrSentinel = await waitFor(timeoutMs: panelTimeoutMs) { () -> AXElement? in
            if let found = findPanel(app: app) { return found }
            if let hit = locateArtifact(named: fallbackName, preferring: saveTo, newerThan: t0) {
                earlyArtifact = hit
                return AXElement(AXUIElementCreateSystemWide())  // sentinel: stop polling
            }
            return nil
        }
        let tPanel = elapsed()
        let panel: AXElement? = earlyArtifact == nil ? panelOrSentinel : nil
        if let panel {
            print(String(format: "  panel     %.3fs (role=%@ id=%@)", tPanel,
                         panel.role ?? "-", panel.identifier ?? "-"))
        } else if earlyArtifact != nil {
            print(String(format: "  panel     %.3fs — none (artifact already written)", tPanel))
        } else {
            print(String(format: "  panel     %.3fs — none found (continuing; the file is the criterion)", tPanel))
        }

        // 4 — read what will be written, then confirm if there is anything to confirm.
        //
        // Not every export raises a panel: ⌘S over an already-located document writes
        // straight to disk. Treating a panel as mandatory would make the instrument
        // unable to measure the simplest completing ritual there is, so it is optional
        // and the file remains the criterion.
        let field = panel?.descendants(maxDepth: 8).first {
            $0.element.identifier == "saveAsNameTextField"
        }?.element ?? panel?.descendants(maxDepth: 8).first {
            $0.element.role == (kAXTextFieldRole as String)
        }?.element

        // Read the name rather than set it. AX `setValue` on a save panel's name field
        // updates the displayed text but does NOT bind to the panel's model — a later
        // replace-confirmation named the *default* filename, not the one that had been
        // set. So the ritual works with whatever the app intends to write and finds the
        // artifact afterwards. Overwriting the same file each run is fine for a
        // reliability loop: freshness is proved by mtime, not by a unique name.
        let intendedName = field?.stringValue
            ?? filename
            ?? app.focusedWindow?.title
            ?? name
        let tFill = elapsed()
        print(String(format: "  fill      %.3fs (expecting \"%@\")", tFill, intendedName))

        var tConfirm = tFill
        if panel != nil {
            guard confirmPanel(app: app, buttonTitle: confirmButton) else {
                throw fail("confirm", "could not actuate \"\(confirmButton)\" via \(confirmMethod.rawValue)")
            }
            tConfirm = elapsed()
        }
        print(String(format: "  confirm   %.3fs%@", tConfirm, panel == nil ? " (no panel — nothing to confirm)" : ""))

        // 5 — the artifact must exist on disk, be newer than this run, and stop growing.
        //
        // A save panel can raise an overwrite confirmation on top of itself, and until
        // it is answered the file never lands — which reads exactly like a silent
        // failure. It is answered inside this poll rather than after a fixed sleep:
        // waiting a fixed 1.5 s for an alert that usually never appears would add that
        // to every run's budget, and polling for "a panel" right after confirming just
        // catches the save panel on its way out.
        var answered = 0
        let found = await waitFor(timeoutMs: fileTimeoutMs) { () -> (path: String, bytes: Int)? in
            if let hit = locateArtifact(named: intendedName, preferring: saveTo, newerThan: t0) {
                return hit
            }
            if answered < 3, let (alert, title) = overwriteAlert(app: app) {
                print("  (answering \"\(title)\" confirmation)")
                _ = actuate(button: title, in: alert)
                answered += 1
            }
            return nil
        }
        guard let found else {
            throw fail("file", "no artifact named \"\(intendedName)\" written since this run started (searched \(saveTo), then Spotlight) within \(fileTimeoutMs)ms")
        }
        let tFile = elapsed()
        print(String(format: "  file      %.3fs (%d bytes) %@", tFile, found.bytes, found.path))

        // 6 — focus must return: the target frontmost, and no panel still owning it
        let restored = await waitFor(timeoutMs: focusTimeoutMs) { () -> Bool? in
            let frontmost = AXElement.focusedApplicationPid() == pid
            let noPanel = findPanel(app: app) == nil
            return (frontmost && noPanel) ? true : nil
        }
        guard restored != nil else {
            // Name whoever holds focus. A background app stealing it is a noisy-machine
            // artifact, not a ritual regression, and the two must not read the same.
            let thiefPid = AXElement.focusedApplicationPid() ?? -1
            let thief = NSRunningApplication(processIdentifier: thiefPid)?.bundleIdentifier ?? "unknown"
            let panelUp = findPanel(app: app) != nil
            throw fail("focus", "focus not restored within \(focusTimeoutMs)ms — frontmost is \(thief) (pid \(thiefPid)); panel still standing: \(panelUp)")
        }
        let tFocus = elapsed()
        print(String(format: "  focus     %.3fs", tFocus))

        let total = elapsed()
        print(String(format: "  PHASES resolve=%.3f press=%.3f panel=%.3f fill=%.3f confirm=%.3f file=%.3f focus=%.3f",
                     tResolve, tPress, tPanel, tFill, tConfirm, tFile, tFocus))
        print(String(format: "  RITUAL ok — total %.3fs", total))
        print(total <= budgetSeconds
              ? String(format: "  ✓ within the 2–%.0fs ritual budget", budgetSeconds)
              : String(format: "  ⚠ exceeded the %.0fs ritual budget", budgetSeconds))
    }

    /// Actuate the panel's confirm button.
    ///
    /// AX can read a save panel and dismiss it, but on a sandboxed app's out-of-process
    /// panel `AXPress` on the default button dismisses without writing a file. A real
    /// click at the button's own coordinates is what a learner does and what works, so
    /// it is the default. The method is selectable because the answer is per-app and
    /// this spike exists to find that out.
    ///
    /// Every global post is gated on the panel still standing, checked immediately
    /// before. That precondition is not ceremony: during diagnosis, keystrokes sent at
    /// a panel that had already closed were typed into the learner's open document.
    private func confirmPanel(app: AXElement, buttonTitle: String) -> Bool {
        guard let standing = findPanel(app: app) else { return false }
        return actuate(button: buttonTitle, in: standing)
    }

    /// A standing panel carrying an overwrite/replace button, and that button's title.
    private func overwriteAlert(app: AXElement) -> (AXElement, String)? {
        guard let standing = findPanel(app: app) else { return nil }
        let title = standing.descendants(maxDepth: 6)
            .filter { $0.element.role == (kAXButtonRole as String) }
            .compactMap { $0.element.title }
            .first { overwriteTitles.contains($0) }
        guard let title else { return nil }
        return (standing, title)
    }

    private func actuate(button buttonTitle: String, in standing: AXElement) -> Bool {
        let button = standing.descendants(maxDepth: 8).first {
            $0.element.role == (kAXButtonRole as String) && $0.element.title == buttonTitle
        }?.element

        switch confirmMethod {
        case .ax:
            guard let button else { return false }
            return button.press()
        case .click:
            guard let button else { return false }
            return clickCentre(of: button)
        case .returnKey:
            // Return activates the default button. Narrower than typing, but it still
            // goes to whatever is frontmost, hence the panel check above.
            for down in [true, false] {
                guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: down) else { return false }
                ev.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.02)
            }
            return true
        }
    }

    /// An element's frame once it has stopped moving: two equal reads, 60 ms apart.
    private func settledFrame(of element: AXElement, timeoutMs: Int = 1500) -> CGRect? {
        var previous: CGRect?
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            guard let current = element.frame, current.width > 0, current.height > 0 else {
                Thread.sleep(forTimeInterval: 0.06)
                continue
            }
            if let previous, previous == current { return current }
            previous = current
            Thread.sleep(forTimeInterval: 0.06)
        }
        return previous
    }

    /// Find the artifact the panel wrote. The save location is not controllable through
    /// AX, so rather than dictate where it goes we look where it is: the expected
    /// directory first, then Spotlight by name. `newerThan` is what makes a run's
    /// success its own — an artifact left by a previous run must not count.
    private func locateArtifact(named name: String, preferring dir: String, newerThan since: Date) -> (path: String, bytes: Int)? {
        var candidates: [String] = []
        let base = (name as NSString).deletingPathExtension
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: dir) {
            candidates += entries.filter { ($0 as NSString).deletingPathExtension == base }
                .map { (dir as NSString).appendingPathComponent($0) }
        }
        candidates += spotlight(base: base)

        for path in candidates {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let bytes = attrs[.size] as? Int, bytes > 0,
                  let modified = attrs[.modificationDate] as? Date,
                  modified >= since else { continue }
            // Size must be stable — an export still being written is not a finished ritual.
            Thread.sleep(forTimeInterval: 0.1)
            guard let again = try? FileManager.default.attributesOfItem(atPath: path),
                  (again[.size] as? Int) == bytes else { continue }
            return (path, bytes)
        }
        return nil
    }

    private func spotlight(base: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-name", base]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map(String.init).prefix(20).map { $0 }
    }

    /// Click an element at the centre of its own AX frame, via the global HID tap.
    ///
    /// A save panel cannot be actuated any other way: AXPress on its default button
    /// dismisses the panel without writing a file, and input posted to the target pid
    /// never arrives because the panel is rendered out-of-process. A click at the
    /// button's real coordinates is both what a learner does and the narrowest
    /// possible use of global input — the caller checks the panel is standing
    /// immediately beforehand, and a stray click is far less destructive than stray
    /// typing would be.
    private func clickCentre(of element: AXElement) -> Bool {
        // Wait for the sheet to stop animating. A sheet is detectable ~130 ms before it
        // has finished sliding in, and a click aimed at the frame read during that
        // window lands somewhere else entirely — the panel simply stays up, which is
        // indistinguishable from the click having been ignored.
        guard let frame = settledFrame(of: element) else { return false }
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        CGWarpMouseCursorPosition(centre)
        CGAssociateMouseAndMouseCursorPosition(1)
        for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
            guard let ev = CGEvent(mouseEventSource: nil, mouseType: type,
                                   mouseCursorPosition: centre, mouseButton: .left) else { return false }
            if type != .mouseMoved { ev.setIntegerValueField(.mouseEventClickState, value: 1) }
            ev.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.03)
        }
        return true
    }

    /// Poll `probe` every 50 ms until it returns non-nil or the timeout expires.
    private func waitFor<T>(timeoutMs: Int, _ probe: () -> T?) async -> T? {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if let value = probe() { return value }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return probe()
    }

    /// App-generic panel search: a sheet arrives AS the focused window; a dialog may
    /// instead be a separate window. Both shapes are accepted.
    private func findPanel(app: AXElement) -> AXElement? {
        let dialogSubroles: Set<String> = [
            kAXDialogSubrole as String, kAXSystemDialogSubrole as String,
        ]
        if let focused = app.focusedWindow {
            if focused.role == (kAXSheetRole as String) { return focused }
            if let subrole = focused.subrole, dialogSubroles.contains(subrole) { return focused }
            if let sheet = focused.descendants(maxDepth: 3)
                .first(where: { $0.element.role == (kAXSheetRole as String) }) {
                return sheet.element
            }
        }
        return app.windows.first {
            $0.role == (kAXSheetRole as String) || ($0.subrole.map(dialogSubroles.contains) ?? false)
        }
    }

    /// Non-zero size, unchanged across two reads — an export still being written is
    /// not a completed ritual.
    private func stableSize(at path: String) -> Int? {
        func size() -> Int? {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let n = attrs[.size] as? Int, n > 0 else { return nil }
            return n
        }
        guard let first = size() else { return nil }
        Thread.sleep(forTimeInterval: 0.1)
        guard let second = size(), second == first else { return nil }
        return second
    }

    /// On failure, say what WAS there. A bare "no" is what let a broken probe read as
    /// a clean measurement for 50 consecutive runs.
    private func dumpDiagnostics(app: AXElement) {
        print("  — diagnostics —")
        let frontPid = AXElement.focusedApplicationPid() ?? -1
        let frontName = NSRunningApplication(processIdentifier: frontPid)?.bundleIdentifier ?? "-"
        print("    frontmost: \(frontName) (pid \(frontPid))")
        if let focused = app.focusedWindow {
            print("    focused window: role=\(focused.role ?? "-") subrole=\(focused.subrole ?? "-") id=\(focused.identifier ?? "-") title=\(focused.title ?? "-")")
            for (depth, el) in focused.descendants(maxDepth: 3).prefix(40) where depth > 0 {
                print("      \(String(repeating: "  ", count: depth))\(el.role ?? "-") id=\(el.identifier ?? "-") title=\(el.title ?? "-")")
            }
        } else {
            print("    focused window: none")
        }
        print("    windows: \(app.windows.map { $0.title ?? $0.role ?? "-" })")
    }
}
