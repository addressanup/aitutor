import EventTapGuard
import Foundation
import IPCServer
import Overlay
import Permissions
import ShellProtocol

// Bridges IPC method calls to the OS organs. Runs off the main actor (IPCServer
// calls it from a Task); overlay work hops to @MainActor. input.key is ALWAYS
// REFUSED at scaffold — the shell-can-refuse invariant, visible from day one.
final class RPCHandlers: IPCServerDelegate {
    private let overlay: OverlayController
    private let gate: PossessionGate

    init(overlay: OverlayController, gate: PossessionGate) {
        self.overlay = overlay
        self.gate = gate
    }

    func handle(method: String, params: [String: JSONValue]) async -> Result<[String: JSONValue], RPCError> {
        switch method {
        case "shell.ping":
            let nonce = params["nonce"]?.stringValue ?? ""
            let ms = Double(Int64(Date().timeIntervalSince1970 * 1000))
            return .success(["nonce": .string(nonce), "shellTimeMs": .number(ms)])

        case "permissions.query":
            let snap = await MainActor.run { Permissions.snapshot() }
            return .success(snap.asObject)

        case "overlay.draw":
            do {
                let spots = try Messages.overlaySpotlights(from: params)
                let ttl = params["ttlMs"].flatMap { if case .number(let n) = $0 { return Int(n) } else { return nil } }
                let drawn = await MainActor.run { self.overlay.drawSpotlights(spots, ttlMs: ttl ?? 2000) }
                return .success(["drawn": .number(Double(drawn))])
            } catch {
                return .failure(RPCError(code: .invalidParams, message: "\(error)"))
            }

        case "overlay.clear":
            await MainActor.run { self.overlay.clear() }
            return .success([:])

        case "input.key":
            // The refusal invariant. The possession gate is idle at scaffold, so no
            // lease is held — the shell never posts synthetic input.
            return .failure(RPCError(
                code: .refused,
                message: "refused: possession_not_held",
                reason: .possessionNotHeld,
                retryable: false
            ))

        default:
            return .failure(RPCError(code: .methodNotFound, message: "unknown method: \(method)"))
        }
    }
}
