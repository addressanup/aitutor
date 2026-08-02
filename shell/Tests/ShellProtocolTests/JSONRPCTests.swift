import Foundation
import Testing
@testable import ShellProtocol

// Decodes the SAME golden fixtures the TypeScript protocol tests use
// (../../../protocol/fixtures) — the cross-language drift guard.

private func fixture(_ name: String) throws -> String {
    // Tests run from the package dir; fixtures live in the sibling protocol package.
    let here = URL(fileURLWithPath: #filePath)
    let root = here.deletingLastPathComponent() // ShellProtocolTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // shell
        .deletingLastPathComponent() // repo root
    let url = root.appendingPathComponent("protocol/fixtures/\(name)")
    return try String(contentsOf: url, encoding: .utf8)
}

@Test func decodesHelloRequest() throws {
    let frame = try JSONRPC.parse(try fixture("hello.request.json"))
    guard case .request(let id, let method, let params) = frame else {
        Issue.record("expected request"); return
    }
    #expect(id == "c-1")
    #expect(method == "session.hello")
    #expect(params["token"]?.stringValue == "fixture-token")
}

@Test func decodesHelloResult() throws {
    let frame = try JSONRPC.parse(try fixture("hello.result.json"))
    guard case .result(_, let result) = frame else { Issue.record("expected result"); return }
    #expect(result["protocolVersion"]?.stringValue == "0.1.0")
}

@Test func decodesOverlayDrawSpotlight() throws {
    let frame = try JSONRPC.parse(try fixture("overlay-draw.request.json"))
    guard case .request(_, let method, let params) = frame else { Issue.record("expected request"); return }
    #expect(method == "overlay.draw")
    let spots = try Messages.overlaySpotlights(from: params)
    #expect(spots.count == 1)
    #expect(spots[0].rect.width == 400)
    #expect(spots[0].caption == "Hello from agent-core")
}

@Test func decodesPossessionEvent() throws {
    let frame = try JSONRPC.parse(try fixture("possession-changed.event.json"))
    guard case .notification(let method, let params) = frame else { Issue.record("expected notification"); return }
    #expect(method == "possession.changed")
    #expect(params["cause"]?.stringValue == "hardware_interrupt")
}

@Test func decodesRefusedError() throws {
    let frame = try JSONRPC.parse(try fixture("error-refused.json"))
    guard case .error(_, let error) = frame else { Issue.record("expected error"); return }
    #expect(error.code == RPCErrorCode.refused.rawValue)
    #expect(error.data?.objectValue?["reason"]?.stringValue == RefuseReason.possessionNotHeld.rawValue)
}

@Test func rejectsBatchFrames() {
    #expect(throws: (any Error).self) { try JSONRPC.parse("[]") }
}

@Test func negotiatesVersions() {
    #expect(Semver.negotiate(min: "0.1.0", max: "0.1.0", supported: ["0.1.0"]) == "0.1.0")
    #expect(Semver.negotiate(min: "0.1.0", max: "0.3.0", supported: ["0.1.0", "0.2.0"]) == "0.2.0")
    #expect(Semver.negotiate(min: "1.0.0", max: "1.2.0", supported: ["0.9.0"]) == nil)
}

@Test func roundTripsResultEncoding() throws {
    let encoded = JSONRPC.encodeResult(id: "c-9", result: ["ok": .bool(true)])
    let frame = try JSONRPC.parse(encoded)
    guard case .result(let id, let result) = frame else { Issue.record("expected result"); return }
    #expect(id == "c-9")
    #expect(result["ok"] == .bool(true))
}
