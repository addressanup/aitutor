import Foundation

// JSON-RPC 2.0 subset — the Swift mirror of @aitutor/protocol. Hand-written for
// v0 (codegen from the zod schemas is future work). The golden fixtures in
// ../../../protocol/fixtures decode against these types in ShellProtocolTests.

public enum ProtocolInfo {
    public static let version = "0.1.0"
    public static let minSupported = "0.1.0"
    public static let defaultPort: UInt16 = 47100
    public static let path = "/ipc"
    public static let helloTimeoutMs = 3000
    public static let closeInvalidToken = 4401
}

public enum RPCErrorCode: Int, Codable, Sendable {
    case parseError = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603
    case refused = -32000
    case incompatibleProtocol = -32001
    case invalidToken = -32002
    case timeout = -32003
    case shellBusy = -32004
}

public enum RefuseReason: String, Codable, Sendable {
    case permissionDenied = "permission_denied"
    case possessionNotHeld = "possession_not_held"
    case appNotWhitelisted = "app_not_whitelisted"
    case forbiddenVerb = "forbidden_verb"
    case learnerInterrupt = "learner_interrupt"
}

/// A JSON value good enough to carry arbitrary params/results/error-data on the wire.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    public var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}

public struct RPCError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: JSONValue?
    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
    public init(code: RPCErrorCode, message: String, reason: RefuseReason? = nil, retryable: Bool? = nil) {
        self.code = code.rawValue
        self.message = message
        var obj: [String: JSONValue] = [:]
        if let reason { obj["reason"] = .string(reason.rawValue) }
        if let retryable { obj["retryable"] = .bool(retryable) }
        self.data = obj.isEmpty ? nil : .object(obj)
    }
}

/// A parsed inbound frame classified by shape.
public enum InboundFrame {
    case request(id: String, method: String, params: [String: JSONValue])
    case notification(method: String, params: [String: JSONValue])
    case result(id: String, result: [String: JSONValue])
    case error(id: String, error: RPCError)
}

public enum FrameError: Error { case malformed(String) }

public enum JSONRPC {
    public static func parse(_ text: String) throws -> InboundFrame {
        guard let data = text.data(using: .utf8) else { throw FrameError.malformed("not utf8") }
        let top = try JSONSerialization.jsonObject(with: data)
        if top is [Any] { throw FrameError.malformed("batch frames unsupported") }
        guard let obj = top as? [String: Any] else { throw FrameError.malformed("frame must be an object") }
        let decoder = JSONDecoder()

        func decodeParams(_ key: String) throws -> [String: JSONValue] {
            guard let raw = obj[key] else { return [:] }
            let d = try JSONSerialization.data(withJSONObject: raw)
            return try decoder.decode([String: JSONValue].self, from: d)
        }

        if let method = obj["method"] as? String {
            let params = try decodeParams("params")
            if let id = obj["id"] as? String {
                return .request(id: id, method: method, params: params)
            }
            return .notification(method: method, params: params)
        }
        if obj["result"] != nil, let id = obj["id"] as? String {
            return .result(id: id, result: try decodeParams("result"))
        }
        if let errRaw = obj["error"], let id = obj["id"] as? String {
            let d = try JSONSerialization.data(withJSONObject: errRaw)
            return .error(id: id, error: try decoder.decode(RPCError.self, from: d))
        }
        throw FrameError.malformed("frame is neither request, notification, nor response")
    }

    public static func encodeResult(id: String, result: [String: JSONValue]) -> String {
        encode(["jsonrpc": .string("2.0"), "id": .string(id), "result": .object(result)])
    }

    public static func encodeError(id: String, error: RPCError) -> String {
        var errObj: [String: JSONValue] = ["code": .number(Double(error.code)), "message": .string(error.message)]
        if let data = error.data { errObj["data"] = data }
        return encode(["jsonrpc": .string("2.0"), "id": .string(id), "error": .object(errObj)])
    }

    public static func encodeNotification(method: String, params: [String: JSONValue]) -> String {
        encode(["jsonrpc": .string("2.0"), "method": .string(method), "params": .object(params)])
    }

    private static func encode(_ obj: [String: JSONValue]) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(obj), let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }
}
