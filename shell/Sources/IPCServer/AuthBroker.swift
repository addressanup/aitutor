import Foundation
import ShellProtocol

// Generates a per-launch session token and writes the discovery/auth handoff file
// the core reads: ~/Library/Application Support/TutorShell/ipc.json (0600).
public struct AuthBroker: Sendable {
    public let token: String
    public let port: UInt16

    public init(port: UInt16) {
        self.port = port
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        self.token = bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static var handoffURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TutorShell/ipc.json")
    }

    public func writeHandoff() {
        let url = Self.handoffURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "port": Int(port),
            "token": token,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "protocolMin": ProtocolInfo.minSupported,
            "protocolMax": ProtocolInfo.version,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else { return }
        try? data.write(to: url)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func removeHandoff() {
        try? FileManager.default.removeItem(at: Self.handoffURL)
    }
}
