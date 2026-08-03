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
        if let running = NSRunningApplication(processIdentifier: pid), !running.isActive {
            running.activate(options: [])
            _ = await waitFor(timeoutMs: 3000) {
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

        // 3 — wait for the panel (diagnostic, not the success criterion)
        let panel = await waitFor(timeoutMs: panelTimeoutMs) { findPanel(app: app) }
        let tPanel = elapsed()
        if let panel {
            print(String(format: "  panel     %.3fs (role=%@ id=%@)", tPanel,
                         panel.role ?? "-", panel.identifier ?? "-"))
        } else {
            print(String(format: "  panel     %.3fs — none found (continuing; the file is the criterion)", tPanel))
        }

        // 4 — fill the name field with an absolute path, then confirm
        guard let panel else { throw fail("panel", "no panel appeared within \(panelTimeoutMs)ms") }
        let nodes = panel.descendants(maxDepth: 8)
        let field = nodes.first { $0.element.identifier == "saveAsNameTextField" }?.element
            ?? nodes.first { $0.element.role == (kAXTextFieldRole as String) }?.element
        guard let field else { throw fail("fill", "no filename text field in the panel") }
        // The name field advertises AXConfirm, and a save panel resolves an absolute
        // path submitted that way — navigating to the directory and taking the base
        // name. That keeps the whole ritual inside Accessibility. The alternative,
        // posting ⌘⇧G and typing, has to go to the global HID tap because the panel
        // is out-of-process, and if the panel ever fails to appear those keystrokes
        // land in the learner's document instead. Not a trade worth making.
        guard field.setValue(name, for: kAXValueAttribute) else {
            throw fail("fill", "could not set the filename field")
        }
        let tFill = elapsed()
        print(String(format: "  fill      %.3fs", tFill))

        // AXConfirm on the name field may itself commit the save (it is Return on the
        // default button). Only press the button if a panel is still standing.
        if let standing = findPanel(app: app) {
            let buttons = standing.descendants(maxDepth: 8)
            guard let button = buttons.first(where: {
                $0.element.role == (kAXButtonRole as String) && $0.element.title == confirmButton
            })?.element else {
                throw fail("confirm", "no button titled \"\(confirmButton)\" in the panel")
            }
            guard clickCentre(of: button) else {
                throw fail("confirm", "confirm button has no readable frame to click")
            }
        }
        let tConfirm = elapsed()
        print(String(format: "  confirm   %.3fs", tConfirm))

        // 5 — the artifact must exist on disk and stop growing
        let landed = await waitFor(timeoutMs: fileTimeoutMs) { stableSize(at: targetPath) }
        guard let landed else {
            throw fail("file", "no stable file at \(targetPath) within \(fileTimeoutMs)ms")
        }
        let tFile = elapsed()
        print(String(format: "  file      %.3fs (%d bytes)", tFile, landed))

        // 6 — focus must return: the target frontmost, and no panel still owning it
        let restored = await waitFor(timeoutMs: focusTimeoutMs) { () -> Bool? in
            let frontmost = AXElement.focusedApplicationPid() == pid
            let noPanel = findPanel(app: app) == nil
            return (frontmost && noPanel) ? true : nil
        }
        guard restored != nil else {
            throw fail("focus", "focus not restored to \(bundleId) within \(focusTimeoutMs)ms")
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
        guard let frame = element.frame else { return false }
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
