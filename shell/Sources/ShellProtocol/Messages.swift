import Foundation

// Typed params/results mirroring protocol/README.md. Version negotiation lives
// here so the app and tests share one implementation.

public enum PermissionState: String, Codable, Sendable {
    case granted, denied
    case notDetermined = "not_determined"
}

public struct PermissionsStatus: Codable, Sendable {
    public var microphone: PermissionState
    public var screenRecording: PermissionState
    public var accessibility: PermissionState
    public var inputMonitoring: PermissionState
    public init(microphone: PermissionState, screenRecording: PermissionState, accessibility: PermissionState, inputMonitoring: PermissionState) {
        self.microphone = microphone
        self.screenRecording = screenRecording
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }
    public var asObject: [String: JSONValue] {
        [
            "microphone": .string(microphone.rawValue),
            "screenRecording": .string(screenRecording.rawValue),
            "accessibility": .string(accessibility.rawValue),
            "inputMonitoring": .string(inputMonitoring.rawValue),
        ]
    }
}

public struct HelloResult: Sendable {
    public let protocolVersion: String
    public let shellVersion: String
    public let sessionId: String
    public let capabilities: [String]
    public init(protocolVersion: String, shellVersion: String, sessionId: String, capabilities: [String]) {
        self.protocolVersion = protocolVersion
        self.shellVersion = shellVersion
        self.sessionId = sessionId
        self.capabilities = capabilities
    }
    public var asObject: [String: JSONValue] {
        [
            "protocolVersion": .string(protocolVersion),
            "shellVersion": .string(shellVersion),
            "sessionId": .string(sessionId),
            "capabilities": .array(capabilities.map { .string($0) }),
        ]
    }
}

/// Screen POINTS, TOP-LEFT origin (the shell converts from Cocoa's bottom-left).
public struct SpotlightRect: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var asObject: [String: JSONValue] {
        [
            "x": .number(x),
            "y": .number(y),
            "width": .number(width),
            "height": .number(height),
        ]
    }
}

/// The rect type is app- and feature-agnostic; `SpotlightRect` is its v0 name, kept so
/// Overlay keeps compiling. v0.2 types spell it `ScreenRect`, which is what it is.
public typealias ScreenRect = SpotlightRect

public struct OverlaySpotlight: Sendable, Equatable {
    public let rect: SpotlightRect
    public let caption: String?
    public init(rect: SpotlightRect, caption: String?) {
        self.rect = rect
        self.caption = caption
    }
}

// MARK: - Protocol v0.2 (additive): ax.query, ax.act, input.click, screen.observe
//
// Schemas and fixtures only. No handler dispatches these yet — a v0.2 shell answers
// METHOD_NOT_FOUND until AXBridge is wired behind them, and advertises `ax`/`input`/
// `screen` in session.hello capabilities only once the matching handler exists.

/// Screen POINTS, TOP-LEFT origin (the shell converts from Cocoa's bottom-left).
public struct ScreenPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) {
        self.x = x; self.y = y
    }
    public var asObject: [String: JSONValue] { ["x": .number(x), "y": .number(y)] }
}

/// Subtree ax.query walks: the whole app, its focused window, or its menu bar.
public enum AXQueryScope: String, Codable, Sendable {
    case application
    case focusedWindow = "focused_window"
    case menuBar = "menu_bar"
}

/// What ax.act does through the ACCESSIBILITY channel — never synthetic HID.
/// Maps onto AXElement: press() / perform(_:) / setValue(_:for:) / menuBarItem(path:)
/// plus NSRunningApplication.activate. Pointer verbs belong to input.click.
public enum AXActVerb: String, Codable, Sendable {
    case press, perform, menu, activate
    case setValue = "set_value"
}

public enum MouseButton: String, Codable, Sendable {
    case left, right
}

/// Chord modifiers, spelled as the shell's action driver accepts them.
public enum KeyModifier: String, Codable, Sendable {
    case cmd, shift, opt, ctrl
}

/// What screen.observe looks at. `.rect` requires the params' explicit rect.
public enum ObserveRegion: String, Codable, Sendable {
    case fullScreen = "full_screen"
    case activeWindow = "active_window"
    case rect
}

/// One accessibility element, flattened — the shape AXElement.descendants(maxDepth:maxNodes:)
/// already yields. `role` is required: an element whose AXRole is unreadable is omitted
/// rather than given an invented role. `frame` is nil when position or size is unreadable.
public struct AXNode: Sendable, Equatable {
    public let depth: Int
    public let role: String
    public let subrole: String?
    public let title: String?
    public let identifier: String?
    public let value: String?
    public let actions: [String]
    public let frame: ScreenRect?
    public init(
        depth: Int,
        role: String,
        subrole: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        value: String? = nil,
        actions: [String],
        frame: ScreenRect? = nil
    ) {
        self.depth = depth
        self.role = role
        self.subrole = subrole
        self.title = title
        self.identifier = identifier
        self.value = value
        self.actions = actions
        self.frame = frame
    }
    public var asObject: [String: JSONValue] {
        var out: [String: JSONValue] = [
            "depth": .number(Double(depth)),
            "role": .string(role),
            "actions": .array(actions.map { .string($0) }),
        ]
        if let subrole { out["subrole"] = .string(subrole) }
        if let title { out["title"] = .string(title) }
        if let identifier { out["identifier"] = .string(identifier) }
        if let value { out["value"] = .string(value) }
        if let frame { out["frame"] = .object(frame.asObject) }
        return out
    }
}

/// How the shell finds ONE element. At least one of identifier/title/menuPath must be
/// present, and the match must advertise the action being asked for.
public struct AXTarget: Sendable, Equatable {
    public let identifier: String?
    public let title: String?
    public let role: String?
    public let menuPath: [String]?
    public init(identifier: String? = nil, title: String? = nil, role: String? = nil, menuPath: [String]? = nil) {
        self.identifier = identifier
        self.title = title
        self.role = role
        self.menuPath = menuPath
    }
}

/// INBOUND ax.query params. maxDepth/maxNodes are bounds, not hints — browser-backed
/// AX trees are large enough that an unbounded walk is a hang.
public struct AXQueryParams: Sendable, Equatable {
    public let bundleId: String
    public let scope: AXQueryScope
    public let maxDepth: Int
    public let maxNodes: Int?
    public let menuPath: [String]?
    public init(bundleId: String, scope: AXQueryScope, maxDepth: Int, maxNodes: Int? = nil, menuPath: [String]? = nil) {
        self.bundleId = bundleId
        self.scope = scope
        self.maxDepth = maxDepth
        self.maxNodes = maxNodes
        self.menuPath = menuPath
    }
}

/// OUTBOUND. `truncated` is true when the walk stopped on maxNodes/maxDepth.
public struct AXQueryResult: Sendable, Equatable {
    public let pid: Int
    public let nodes: [AXNode]
    public let truncated: Bool
    public init(pid: Int, nodes: [AXNode], truncated: Bool) {
        self.pid = pid
        self.nodes = nodes
        self.truncated = truncated
    }
    public var asObject: [String: JSONValue] {
        [
            "pid": .number(Double(pid)),
            "nodes": .array(nodes.map { .object($0.asObject) }),
            "truncated": .bool(truncated),
        ]
    }
}

/// INBOUND ax.act params. Per verb: press/perform need target (perform also needs
/// action); setValue needs target + value; menu needs target.menuPath; activate needs
/// neither. The per-verb check belongs to the handler, not the decoder.
public struct AXActParams: Sendable, Equatable {
    public let bundleId: String
    public let verb: AXActVerb
    public let target: AXTarget?
    public let action: String?
    public let value: String?
    public init(bundleId: String, verb: AXActVerb, target: AXTarget? = nil, action: String? = nil, value: String? = nil) {
        self.bundleId = bundleId
        self.verb = verb
        self.target = target
        self.action = action
        self.value = value
    }
}

/// OUTBOUND. `performed` false means the element resolved but the AX API declined —
/// a refusal by the SHELL is an error frame (REFUSED), never a false here.
public struct AXActResult: Sendable, Equatable {
    public let performed: Bool
    public let matched: AXNode?
    public init(performed: Bool, matched: AXNode? = nil) {
        self.performed = performed
        self.matched = matched
    }
    public var asObject: [String: JSONValue] {
        var out: [String: JSONValue] = ["performed": .bool(performed)]
        if let matched { out["matched"] = .object(matched.asObject) }
        return out
    }
}

/// INBOUND input.click params. Same posture and same refusal invariant as input.key:
/// REFUSED (possession_not_held) without a lease. Takes a pid, not a bundle id,
/// because CGEventPostToPid takes a pid — and because input.key froze that shape in v0.
public struct InputClickParams: Sendable, Equatable {
    public let pid: Int
    public let point: ScreenPoint
    public let button: MouseButton
    public let clickCount: Int
    public let modifiers: [KeyModifier]
    public init(pid: Int, point: ScreenPoint, button: MouseButton = .left, clickCount: Int = 1, modifiers: [KeyModifier] = []) {
        self.pid = pid
        self.point = point
        self.button = button
        self.clickCount = clickCount
        self.modifiers = modifiers
    }
}

/// OUTBOUND — the same pair input.key answers with.
public struct InputClickResult: Sendable, Equatable {
    public let posted: Bool
    public let dryRun: Bool
    public init(posted: Bool, dryRun: Bool) {
        self.posted = posted
        self.dryRun = dryRun
    }
    public var asObject: [String: JSONValue] {
        ["posted": .bool(posted), "dryRun": .bool(dryRun)]
    }
}

/// INBOUND screen.observe params. `rect` is required when region is `.rect`.
public struct ScreenObserveParams: Sendable, Equatable {
    public let region: ObserveRegion
    public let rect: ScreenRect?
    public init(region: ObserveRegion, rect: ScreenRect? = nil) {
        self.region = region
        self.rect = rect
    }
}

/// OUTBOUND — metadata only, on purpose. CapturePipeline.captureOnce() is still a stub,
/// so the honest answer today is imageAvailable = false with the region the shell WOULD
/// have captured. No image bytes cross this wire in v0.2.
public struct ScreenObserveResult: Sendable, Equatable {
    public let atMs: Double
    public let frame: ScreenRect
    public let imageAvailable: Bool
    public init(atMs: Double, frame: ScreenRect, imageAvailable: Bool) {
        self.atMs = atMs
        self.frame = frame
        self.imageAvailable = imageAvailable
    }
    public var asObject: [String: JSONValue] {
        [
            "atMs": .number(atMs),
            "frame": .object(frame.asObject),
            "imageAvailable": .bool(imageAvailable),
        ]
    }
}

public enum MessageDecodeError: Error { case badParams(String) }

public enum Messages {
    /// Decode overlay.draw spotlight items from raw params.
    public static func overlaySpotlights(from params: [String: JSONValue]) throws -> [OverlaySpotlight] {
        guard case .array(let items)? = params["items"] else {
            throw MessageDecodeError.badParams("items must be an array")
        }
        return try items.map { item in
            guard case .object(let o) = item,
                  case .object(let r)? = o["rect"],
                  case .number(let x)? = r["x"],
                  case .number(let y)? = r["y"],
                  case .number(let w)? = r["width"],
                  case .number(let h)? = r["height"]
            else { throw MessageDecodeError.badParams("malformed spotlight item") }
            let caption = o["caption"]?.stringValue
            return OverlaySpotlight(rect: SpotlightRect(x: x, y: y, width: w, height: h), caption: caption)
        }
    }

    /// Decode ax.query params from raw params.
    public static func axQuery(from params: [String: JSONValue]) throws -> AXQueryParams {
        guard case .string(let bundleId)? = params["bundleId"], !bundleId.isEmpty else {
            throw MessageDecodeError.badParams("bundleId must be a non-empty string")
        }
        guard case .string(let rawScope)? = params["scope"], let scope = AXQueryScope(rawValue: rawScope) else {
            throw MessageDecodeError.badParams("scope must be application|focused_window|menu_bar")
        }
        guard case .number(let depth)? = params["maxDepth"], depth > 0 else {
            throw MessageDecodeError.badParams("maxDepth must be a positive number")
        }
        var maxNodes: Int?
        if let raw = params["maxNodes"] {
            guard case .number(let n) = raw, n > 0 else {
                throw MessageDecodeError.badParams("maxNodes must be a positive number")
            }
            maxNodes = Int(n)
        }
        return AXQueryParams(
            bundleId: bundleId,
            scope: scope,
            maxDepth: Int(depth),
            maxNodes: maxNodes,
            menuPath: try strings(params["menuPath"], field: "menuPath")
        )
    }

    /// Decode ax.act params from raw params. Per-verb field requirements are the
    /// handler's to enforce — this decoder only rejects wrong SHAPES.
    public static func axAct(from params: [String: JSONValue]) throws -> AXActParams {
        guard case .string(let bundleId)? = params["bundleId"], !bundleId.isEmpty else {
            throw MessageDecodeError.badParams("bundleId must be a non-empty string")
        }
        guard case .string(let rawVerb)? = params["verb"], let verb = AXActVerb(rawValue: rawVerb) else {
            throw MessageDecodeError.badParams("verb must be press|perform|set_value|menu|activate")
        }
        var target: AXTarget?
        if let raw = params["target"] {
            guard case .object(let t) = raw else {
                throw MessageDecodeError.badParams("target must be an object")
            }
            target = AXTarget(
                identifier: t["identifier"]?.stringValue,
                title: t["title"]?.stringValue,
                role: t["role"]?.stringValue,
                menuPath: try strings(t["menuPath"], field: "target.menuPath")
            )
        }
        return AXActParams(
            bundleId: bundleId,
            verb: verb,
            target: target,
            action: params["action"]?.stringValue,
            value: params["value"]?.stringValue
        )
    }

    /// Decode input.click params from raw params.
    public static func inputClick(from params: [String: JSONValue]) throws -> InputClickParams {
        guard case .number(let pid)? = params["pid"], pid > 0 else {
            throw MessageDecodeError.badParams("pid must be a positive number")
        }
        guard case .object(let p)? = params["point"],
              case .number(let x)? = p["x"],
              case .number(let y)? = p["y"]
        else { throw MessageDecodeError.badParams("point must be {x, y}") }

        var button = MouseButton.left
        if let raw = params["button"] {
            guard case .string(let name) = raw, let parsed = MouseButton(rawValue: name) else {
                throw MessageDecodeError.badParams("button must be left|right")
            }
            button = parsed
        }
        var clickCount = 1
        if let raw = params["clickCount"] {
            guard case .number(let n) = raw, n == 1 || n == 2 else {
                throw MessageDecodeError.badParams("clickCount must be 1 or 2")
            }
            clickCount = Int(n)
        }
        var modifiers: [KeyModifier] = []
        if let names = try strings(params["modifiers"], field: "modifiers") {
            modifiers = try names.map { name in
                guard let mod = KeyModifier(rawValue: name) else {
                    throw MessageDecodeError.badParams("unknown modifier: \(name)")
                }
                return mod
            }
        }
        return InputClickParams(
            pid: Int(pid),
            point: ScreenPoint(x: x, y: y),
            button: button,
            clickCount: clickCount,
            modifiers: modifiers
        )
    }

    /// Decode screen.observe params from raw params.
    public static func screenObserve(from params: [String: JSONValue]) throws -> ScreenObserveParams {
        guard case .string(let rawRegion)? = params["region"], let region = ObserveRegion(rawValue: rawRegion) else {
            throw MessageDecodeError.badParams("region must be full_screen|active_window|rect")
        }
        var rect: ScreenRect?
        if let raw = params["rect"] {
            guard case .object(let r) = raw,
                  case .number(let x)? = r["x"],
                  case .number(let y)? = r["y"],
                  case .number(let w)? = r["width"],
                  case .number(let h)? = r["height"]
            else { throw MessageDecodeError.badParams("rect must be {x, y, width, height}") }
            rect = ScreenRect(x: x, y: y, width: w, height: h)
        }
        guard region != .rect || rect != nil else {
            throw MessageDecodeError.badParams("region 'rect' requires rect")
        }
        return ScreenObserveParams(region: region, rect: rect)
    }

    /// Optional array-of-strings field. nil when absent; throws when present but wrong.
    private static func strings(_ value: JSONValue?, field: String) throws -> [String]? {
        guard let value else { return nil }
        guard case .array(let items) = value else {
            throw MessageDecodeError.badParams("\(field) must be an array of strings")
        }
        return try items.map {
            guard let s = $0.stringValue else {
                throw MessageDecodeError.badParams("\(field) must be an array of strings")
            }
            return s
        }
    }
}

// MARK: - Semver negotiation (mirror of protocol/src/negotiate.ts)

public enum Semver {
    public static func parse(_ v: String) -> (Int, Int, Int)? {
        let parts = v.trimmingCharacters(in: .whitespaces).split(separator: ".")
        guard parts.count == 3, let a = Int(parts[0]), let b = Int(parts[1]), let c = Int(parts[2]) else {
            return nil
        }
        return (a, b, c)
    }

    public static func compare(_ a: String, _ b: String) -> Int? {
        guard let pa = parse(a), let pb = parse(b) else { return nil }
        if pa.0 != pb.0 { return pa.0 < pb.0 ? -1 : 1 }
        if pa.1 != pb.1 { return pa.1 < pb.1 ? -1 : 1 }
        if pa.2 != pb.2 { return pa.2 < pb.2 ? -1 : 1 }
        return 0
    }

    /// Highest supported version inside [min, max]; nil if none overlap.
    public static func negotiate(min: String, max: String, supported: [String]) -> String? {
        guard parse(min) != nil, parse(max) != nil else { return nil }
        var best: String? = nil
        for s in supported {
            guard parse(s) != nil else { continue }
            guard let lo = compare(s, min), let hi = compare(s, max), lo >= 0, hi <= 0 else { continue }
            if best == nil || (compare(s, best!) ?? -1) > 0 { best = s }
        }
        return best
    }
}
