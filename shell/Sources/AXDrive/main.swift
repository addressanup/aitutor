import AXBridge
import AppKit
import ArgumentParser
import Foundation

// Headless action driver (spike tooling). App-GENERIC: performs scripted UI
// actions against a target app so the density/ritual spikes can run without a
// human at the keyboard. Same single Accessibility grant as axprobe; keystrokes
// post via CGEventPostToPid — the same delivery posture the product mandates.
//
// Script: one command per line; blank lines ignored; '#' starts a comment
// anywhere on a line (so literal '#' cannot appear in `type` text).
//   activate                    bring the app frontmost, wait for it
//   menu File>Export as PDF…    press a menu item along a title path
//   key cmd+shift+z             post a key chord (see keyCodes below)
//   type Hello world            post text as unicode keyboard events
//   sleep 500                   pause N milliseconds
@main
struct AXDrive: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "axdrive",
        abstract: "Perform scripted keyboard/menu actions against a target app via Accessibility."
    )

    @Option(name: .long, help: "Bundle id of the target app.")
    var bundleId: String

    @Option(name: .long, help: "Script file path, or '-' for stdin.")
    var script: String

    @Option(name: .long, help: "Delay between commands, in milliseconds.")
    var stepDelayMs: Int = 150

    mutating func run() throws {
        guard AXIsProcessTrusted() else {
            FileHandle.standardError.write(Data("Accessibility not granted to this terminal. Grant it, then retry.\n".utf8))
            throw ExitCode.failure
        }
        guard let pid = AXElement.pid(forBundleId: bundleId) else {
            FileHandle.standardError.write(Data("App not running: \(bundleId)\n".utf8))
            throw ExitCode.failure
        }

        let text: String
        if script == "-" {
            text = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
        } else {
            text = try String(contentsOfFile: script, encoding: .utf8)
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let noComment = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first.map(String.init) ?? ""
            let line = noComment.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            try execute(line, pid: pid)
            Thread.sleep(forTimeInterval: Double(stepDelayMs) / 1000.0)
        }
    }

    private func execute(_ line: String, pid: pid_t) throws {
        let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
        let verb = parts[0]
        let arg = parts.count > 1 ? parts[1] : ""

        switch verb {
        case "activate":
            guard let app = NSRunningApplication(processIdentifier: pid) else {
                throw ValidationError("no running app for pid \(pid)")
            }
            app.activate(options: [])
            Thread.sleep(forTimeInterval: 0.3)

        case "menu":
            let path = arg.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
            let app = AXElement.application(pid: pid)
            guard let item = app.menuBarItem(path: path) else {
                throw ValidationError("menu item not found: \(arg)")
            }
            guard item.press() else { throw ValidationError("menu press failed: \(arg)") }

        case "key":
            try postChord(arg, pid: pid)

        case "type":
            postText(arg, pid: pid)

        case "sleep":
            guard let ms = Int(arg) else { throw ValidationError("sleep wants milliseconds: \(line)") }
            Thread.sleep(forTimeInterval: Double(ms) / 1000.0)

        default:
            throw ValidationError("unknown command: \(line)")
        }
    }

    private func postChord(_ chord: String, pid: pid_t) throws {
        var flags: CGEventFlags = []
        var keyName: String?
        for piece in chord.lowercased().split(separator: "+").map(String.init) {
            switch piece {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "opt", "option", "alt": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            default: keyName = piece
            }
        }
        guard let name = keyName, let code = Self.keyCodes[name] else {
            throw ValidationError("unknown key in chord: \(chord)")
        }
        for down in [true, false] {
            guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
            ev.flags = flags
            ev.postToPid(pid)
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    private func postText(_ text: String, pid: pid_t) {
        for scalar in text.unicodeScalars {
            var chars = Array(String(scalar).utf16)
            for down in [true, false] {
                guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { continue }
                ev.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                ev.postToPid(pid)
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    // US-layout virtual keycodes — enough for spike scripts.
    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "return": 36, "enter": 36, "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
        ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "delete": 51, "backspace": 51, "esc": 53, "escape": 53,
        "left": 123, "right": 124, "down": 125, "up": 126,
    ]
}
