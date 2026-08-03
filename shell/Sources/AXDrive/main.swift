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
//   moveto 50% 60%              move the pointer (window-relative)
//   click 50% 60%               left click at a point
//   doubleclick 50% 60%         left double-click at a point
//   drag 20% 30% 60% 70%        press, drag along a path, release
//
// Coordinates are relative to the target's focused window and accept either points
// from its top-left ("click 300 220") or fractions of its size ("click 50% 60%").
// Fractions are what survive a different display on another machine, so driver sets
// meant for replication should prefer them. Canvas-heavy apps are unreachable by
// keyboard alone, and the density question is precisely about those surfaces.
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

    @Flag(name: .long, help: "Post input to the global HID tap instead of the target pid. Required to drive out-of-process panels (save/open sheets), which never receive pid-targeted input.")
    var globalInput = false

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

        case "setvalue":
            // setvalue <ax-identifier> <text>
            let bits = arg.split(separator: " ", maxSplits: 1).map(String.init)
            guard bits.count == 2 else { throw ValidationError("setvalue wants <identifier> <text>: \(line)") }
            let app = AXElement.application(pid: pid)
            guard let window = app.focusedWindow else {
                throw ValidationError("no focused window for setvalue")
            }
            guard let node = window.descendants(maxDepth: 8).first(where: {
                $0.element.identifier == bits[0]
            })?.element else {
                throw ValidationError("no element with identifier \(bits[0])")
            }
            guard node.setValue(bits[1], for: kAXValueAttribute) else {
                throw ValidationError("setvalue failed on \(bits[0])")
            }

        case "press":
            // Press a button by title inside the focused window. Needed because a
            // save panel is rendered by an out-of-process service: keystrokes posted
            // to the target pid never reach it, so `key esc` cannot dismiss it. AX
            // does reach it, since AppKit bridges the panel's tree into the app.
            let app = AXElement.application(pid: pid)
            guard let window = app.focusedWindow else {
                throw ValidationError("no focused window to search for button: \(arg)")
            }
            // Match on title OR identifier, and on anything that advertises AXPress —
            // not just AXButton, since popups and disclosure triangles are pressable too.
            let target = window.descendants(maxDepth: 8).first {
                ($0.element.title == arg || $0.element.identifier == arg)
                    && $0.element.actions().contains(kAXPressAction as String)
            }
            guard let target else { throw ValidationError("no pressable element titled/identified \(arg)") }
            guard target.element.press() else { throw ValidationError("press failed: \(arg)") }

        case "moveto":
            let pt = try resolvePoint(arg, expecting: 2, pid: pid)[0]
            warp(to: pt)
            postMouse(.mouseMoved, at: pt, pid: pid, clickState: 0)

        case "click", "doubleclick":
            let pt = try resolvePoint(arg, expecting: 2, pid: pid)[0]
            let clicks = verb == "doubleclick" ? 2 : 1
            warp(to: pt)
            postMouse(.mouseMoved, at: pt, pid: pid, clickState: 0)
            for click in 1...clicks {
                postMouse(.leftMouseDown, at: pt, pid: pid, clickState: click)
                Thread.sleep(forTimeInterval: 0.04)
                postMouse(.leftMouseUp, at: pt, pid: pid, clickState: click)
                if click < clicks { Thread.sleep(forTimeInterval: 0.06) }
            }

        case "drag":
            let pts = try resolvePoint(arg, expecting: 4, pid: pid)
            let (from, to) = (pts[0], pts[1])
            warp(to: from)
            postMouse(.mouseMoved, at: from, pid: pid, clickState: 0)
            postMouse(.leftMouseDown, at: from, pid: pid, clickState: 1)
            // Interpolated intermediate moves: canvas apps track drags through
            // leftMouseDragged, and a down→up pair alone reads as a click.
            let steps = 12
            for i in 1...steps {
                let f = Double(i) / Double(steps)
                let mid = CGPoint(x: from.x + (to.x - from.x) * f, y: from.y + (to.y - from.y) * f)
                warp(to: mid)
                postMouse(.leftMouseDragged, at: mid, pid: pid, clickState: 1)
                Thread.sleep(forTimeInterval: 0.012)
            }
            postMouse(.leftMouseUp, at: to, pid: pid, clickState: 1)

        default:
            throw ValidationError("unknown command: \(line)")
        }
    }

    /// Parse `expecting` coordinate tokens into absolute screen points, pairwise.
    /// Each token is either points from the focused window's top-left ("300") or a
    /// fraction of the window's size ("50%").
    private func resolvePoint(_ arg: String, expecting: Int, pid: pid_t) throws -> [CGPoint] {
        let tokens = arg.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard tokens.count == expecting else {
            throw ValidationError("expected \(expecting) coordinates, got \(tokens.count): \(arg)")
        }
        guard let frame = AXElement.application(pid: pid).focusedWindow?.frame else {
            throw ValidationError("no focused window to resolve coordinates against")
        }
        var out: [CGPoint] = []
        for pair in stride(from: 0, to: tokens.count, by: 2) {
            let x = try axis(tokens[pair], span: frame.width, origin: frame.minX)
            let y = try axis(tokens[pair + 1], span: frame.height, origin: frame.minY)
            out.append(CGPoint(x: x, y: y))
        }
        return out
    }

    private func axis(_ token: String, span: CGFloat, origin: CGFloat) throws -> CGFloat {
        if token.hasSuffix("%") {
            guard let pct = Double(token.dropLast()) else {
                throw ValidationError("bad percentage: \(token)")
            }
            return origin + span * CGFloat(pct / 100.0)
        }
        guard let pts = Double(token) else { throw ValidationError("bad coordinate: \(token)") }
        return origin + CGFloat(pts)
    }

    /// Move the real cursor too. Apps hit-test and hover off the actual pointer, so a
    /// posted event at a location the cursor never visited is not what a learner does.
    private func warp(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint, pid: pid_t, clickState: Int) {
        guard let ev = CGEvent(mouseEventSource: nil, mouseType: type,
                               mouseCursorPosition: point, mouseButton: .left) else { return }
        if clickState > 0 { ev.setIntegerValueField(.mouseEventClickState, value: Int64(clickState)) }
        if globalInput { ev.post(tap: .cghidEventTap) } else { ev.postToPid(pid) }
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
            if globalInput { ev.post(tap: .cghidEventTap) } else { ev.postToPid(pid) }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    private func postText(_ text: String, pid: pid_t) {
        for scalar in text.unicodeScalars {
            var chars = Array(String(scalar).utf16)
            for down in [true, false] {
                guard let ev = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { continue }
                ev.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                if globalInput { ev.post(tap: .cghidEventTap) } else { ev.postToPid(pid) }
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
