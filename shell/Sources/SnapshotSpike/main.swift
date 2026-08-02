import AXBridge
import AppKit
import ArgumentParser
import Foundation

// Snapshot-ritual rehearsal (execution-plan §7 spike b). App-GENERIC: drive a menu
// action via AX along a title path, wait for a save sheet if one appears, and time
// each step against the 2–4s ritual budget. Rehearse on TextEdit's "File>Export as
// PDF…" before pointing it at any app's export.
@main
struct SnapshotSpike: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "snapshot-spike",
        abstract: "Drive a menu action via Accessibility and time it against the ritual budget."
    )

    @Option(name: .long, help: "Bundle id of the target app.")
    var bundleId: String

    @Option(name: .long, help: "Menu path, '>'-separated, e.g. \"File>Export as PDF…\"")
    var menuPath: String

    @Option(name: .long, help: "Directory to note as the intended save location.")
    var saveTo: String = "/tmp/aitutor-spike-out"

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
        print("Target \(bundleId) (pid \(pid)) — menu path \(path)")

        let t0 = Date()
        guard let item = app.menuBarItem(path: path) else {
            FileHandle.standardError.write(Data("Menu item not found along path \(path). Is a document open/focused?\n".utf8))
            throw ExitCode.failure
        }
        let tResolve = Date().timeIntervalSince(t0)
        print(String(format: "  resolved menu item in %.3fs (title: %@)", tResolve, item.title ?? "-"))

        let pressed = item.press()
        let tPress = Date().timeIntervalSince(t0)
        print(String(format: "  pressed in %.3fs — success: %@", tPress, pressed ? "yes" : "no"))

        // Poll briefly for a save sheet on the app's focused window.
        var sawSheet = false
        for _ in 0..<20 {
            if let win = app.attribute(kAXFocusedWindowAttribute as String).map({ AXElement($0 as! AXUIElement) }),
               win.children().contains(where: { $0.role == (kAXSheetRole as String) }) {
                sawSheet = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let tTotal = Date().timeIntervalSince(t0)
        print(String(format: "  save sheet appeared: %@ (total %.3fs)", sawSheet ? "yes" : "no", tTotal))
        print("  intended save dir: \(saveTo)")
        print(tTotal <= 4.0 ? "  ✓ within the 2–4s ritual budget" : "  ⚠ exceeded the 4s ritual budget")
    }
}
