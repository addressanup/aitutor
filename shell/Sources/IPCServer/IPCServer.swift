import Foundation
import Network
import ShellProtocol

// WebSocket server on 127.0.0.1 built on Network.framework (NWListener +
// NWProtocolWebSocket) — zero external deps. One authenticated session at a time;
// a new valid hello replaces the old connection (dev-friendly). Methods are
// dispatched to handlers the app registers; the server never imports Overlay.

public protocol IPCServerDelegate: AnyObject, Sendable {
    /// Handle a request method. Return a result object, or throw an RPCError-carrying
    /// error to send a JSON-RPC error. Runs off the main actor; handlers hop as needed.
    func handle(method: String, params: [String: JSONValue]) async -> Result<[String: JSONValue], RPCError>
}

public final class IPCServer: @unchecked Sendable {
    private let port: UInt16
    private let token: String
    private let queue = DispatchQueue(label: "ipc-server")
    private var listener: NWListener?
    private var connection: NWConnection?
    private var authed = false
    public weak var delegate: IPCServerDelegate?

    public init(port: UInt16, token: String) {
        self.port = port
        self.token = token
    }

    public func start() throws {
        let params = NWParameters.tcp
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)
        // localhost only
        params.requiredInterfaceType = .loopback

        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in
            self?.adopt(conn)
        }
        listener.start(queue: queue)
    }

    public func stop() {
        connection?.cancel()
        listener?.cancel()
    }

    private func adopt(_ conn: NWConnection) {
        // Replace any existing session.
        connection?.cancel()
        connection = conn
        authed = false
        conn.start(queue: queue)
        receive(on: conn)

        // Enforce the hello deadline.
        queue.asyncAfter(deadline: .now() + .milliseconds(ProtocolInfo.helloTimeoutMs)) { [weak self] in
            guard let self, self.connection === conn, !self.authed else { return }
            conn.cancel()
        }
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, context, _, error in
            guard let self else { return }
            if let data, let context, !data.isEmpty {
                let isText = (context.protocolMetadata(definition: NWProtocolWebSocket.definition)
                    as? NWProtocolWebSocket.Metadata)?.opcode == .text
                if isText, let text = String(data: data, encoding: .utf8) {
                    self.onText(text, conn: conn)
                }
            }
            if error == nil { self.receive(on: conn) }
        }
    }

    private func onText(_ text: String, conn: NWConnection) {
        let frame: InboundFrame
        do {
            frame = try JSONRPC.parse(text)
        } catch {
            return
        }
        guard case .request(let id, let method, let params) = frame else { return }

        if method == "session.hello" {
            handleHello(id: id, params: params, conn: conn)
            return
        }
        guard authed else {
            send(JSONRPC.encodeError(id: id, error: RPCError(code: .invalidToken, message: "not authenticated")), conn: conn)
            return
        }
        Task { [weak self] in
            guard let self, let delegate = self.delegate else { return }
            let result = await delegate.handle(method: method, params: params)
            switch result {
            case .success(let obj): self.send(JSONRPC.encodeResult(id: id, result: obj), conn: conn)
            case .failure(let err): self.send(JSONRPC.encodeError(id: id, error: err), conn: conn)
            }
        }
    }

    private func handleHello(id: String, params: [String: JSONValue], conn: NWConnection) {
        guard params["token"]?.stringValue == token else {
            send(JSONRPC.encodeError(id: id, error: RPCError(code: .invalidToken, message: "bad token")), conn: conn)
            conn.cancel()
            return
        }
        let min = params["protocolMin"]?.stringValue ?? ProtocolInfo.version
        let max = params["protocolMax"]?.stringValue ?? ProtocolInfo.version
        guard let agreed = Semver.negotiate(min: min, max: max, supported: [ProtocolInfo.version]) else {
            send(JSONRPC.encodeError(id: id, error: RPCError(code: .incompatibleProtocol, message: "no common protocol version")), conn: conn)
            conn.cancel()
            return
        }
        authed = true
        let result = HelloResult(
            protocolVersion: agreed,
            shellVersion: "0.1.0",
            sessionId: "sess-\(UUID().uuidString.prefix(8))",
            capabilities: ["permissions", "overlay"]
        )
        send(JSONRPC.encodeResult(id: id, result: result.asObject), conn: conn)
    }

    /// Push a shell→core event notification.
    public func emit(method: String, params: [String: JSONValue]) {
        guard authed, let conn = connection else { return }
        send(JSONRPC.encodeNotification(method: method, params: params), conn: conn)
    }

    private func send(_ text: String, conn: NWConnection) {
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [meta])
        conn.send(content: text.data(using: .utf8), contentContext: context, completion: .contentProcessed { _ in })
    }
}
