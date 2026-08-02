import AppKit
import EventTapGuard
import IPCServer
import Overlay
import Permissions
import ShellProtocol
import SwiftUI

// MainActor-owned app state: permission snapshot, IPC server lifecycle, overlay
// controller, possession gate, and NSWorkspace frontmost pushes. The server's
// handler bounces back to the main actor for overlay work.
@MainActor
@Observable
final class AppModel {
    var permissions = Permissions.snapshot()
    private(set) var port: UInt16 = ProtocolInfo.defaultPort
    private(set) var serverRunning = false

    private let overlay = OverlayController()
    private let gate = PossessionGate()
    private var server: IPCServer?
    private var broker: AuthBroker?
    private var handler: RPCHandlers?
    private var frontmostObserver: NSObjectProtocol?

    func start() {
        let envPort = ProcessInfo.processInfo.environment["TUTOR_IPC_PORT"].flatMap { UInt16($0) }
        let broker = AuthBroker(port: envPort ?? ProtocolInfo.defaultPort)
        self.broker = broker
        self.port = broker.port

        let server = IPCServer(port: broker.port, token: broker.token)
        let handler = RPCHandlers(overlay: overlay, gate: gate)
        server.delegate = handler
        self.server = server
        self.handler = handler

        do {
            try server.start()
            broker.writeHandoff()
            serverRunning = true
        } catch {
            NSLog("IPC server failed to start: \(error)")
            serverRunning = false
        }

        observeFrontmost(server: server)
        refreshPermissions()
    }

    func stop() {
        server?.stop()
        broker?.removeHandoff()
        if let frontmostObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(frontmostObserver)
        }
    }

    func refreshPermissions() {
        permissions = Permissions.snapshot()
    }

    private func observeFrontmost(server: IPCServer) {
        frontmostObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let ms = Int64(Date().timeIntervalSince1970 * 1000)
            server.emit(method: "workspace.frontmostChanged", params: [
                "bundleId": app?.bundleIdentifier.map { JSONValue.string($0) } ?? .null,
                "appName": app?.localizedName.map { JSONValue.string($0) } ?? .null,
                "atMs": .number(Double(ms)),
            ])
        }
    }
}
