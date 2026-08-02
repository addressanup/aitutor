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
}

public struct OverlaySpotlight: Sendable, Equatable {
    public let rect: SpotlightRect
    public let caption: String?
    public init(rect: SpotlightRect, caption: String?) {
        self.rect = rect
        self.caption = caption
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
