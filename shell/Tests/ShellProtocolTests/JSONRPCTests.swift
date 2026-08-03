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

// MARK: - Protocol v0.2 (additive)
//
// The v0 fixtures above are frozen as the N−1 regression guard; these are the new
// ones. Result fixtures are checked by BUILDING the outbound struct and comparing its
// asObject to the fixture — the drift guard has to run in the encoding direction too,
// since the shell writes results and only ever reads params.

@Test func decodesHelloV02Request() throws {
    let frame = try JSONRPC.parse(try fixture("hello-v02.request.json"))
    guard case .request(_, let method, let params) = frame else { Issue.record("expected request"); return }
    #expect(method == "session.hello")
    #expect(params["protocolMin"]?.stringValue == ProtocolInfo.minSupported)
    #expect(params["protocolMax"]?.stringValue == ProtocolInfo.version)
}

@Test func decodesHelloV02Result() throws {
    let frame = try JSONRPC.parse(try fixture("hello-v02.result.json"))
    guard case .result(_, let result) = frame else { Issue.record("expected result"); return }
    #expect(result["protocolVersion"]?.stringValue == ProtocolInfo.version)
    let built = HelloResult(
        protocolVersion: "0.2.0",
        shellVersion: "0.2.0",
        sessionId: "sess-fixture-v02",
        capabilities: ["permissions", "overlay", "ax", "input", "screen"]
    )
    #expect(built.asObject == result)
}

@Test func decodesAXQueryRequest() throws {
    let frame = try JSONRPC.parse(try fixture("ax-query.request.json"))
    guard case .request(_, let method, let params) = frame else { Issue.record("expected request"); return }
    #expect(method == "ax.query")
    let query = try Messages.axQuery(from: params)
    #expect(query.bundleId == "com.example.FixtureApp")
    #expect(query.scope == .focusedWindow)
    #expect(query.maxDepth == 4)
    #expect(query.maxNodes == 200)
    #expect(query.menuPath == nil)
}

@Test func decodesAXQueryResult() throws {
    let frame = try JSONRPC.parse(try fixture("ax-query.result.json"))
    guard case .result(_, let result) = frame else { Issue.record("expected result"); return }
    let built = AXQueryResult(
        pid: 4242,
        nodes: [
            AXNode(
                depth: 0, role: "AXWindow", title: "Fixture Window",
                actions: ["AXRaise"],
                frame: ScreenRect(x: 100, y: 80, width: 900, height: 600)
            ),
            AXNode(
                depth: 1, role: "AXButton", subrole: "AXFixtureSubrole",
                title: "Fixture Button", identifier: "fixture-primary-button",
                actions: ["AXPress"],
                frame: ScreenRect(x: 140, y: 520, width: 120, height: 32)
            ),
            AXNode(
                depth: 1, role: "AXTextArea", identifier: "fixture-text-area",
                value: "fixture body text", actions: [],
                frame: ScreenRect(x: 120, y: 140, width: 860, height: 360)
            ),
        ],
        truncated: false
    )
    #expect(built.asObject == result)
}

@Test func decodesAXActRequest() throws {
    let frame = try JSONRPC.parse(try fixture("ax-act.request.json"))
    guard case .request(_, let method, let params) = frame else { Issue.record("expected request"); return }
    #expect(method == "ax.act")
    let act = try Messages.axAct(from: params)
    #expect(act.verb == .press)
    #expect(act.target?.identifier == "fixture-primary-button")
    #expect(act.target?.role == "AXButton")
    #expect(act.value == nil)
}

@Test func decodesAXActResult() throws {
    let frame = try JSONRPC.parse(try fixture("ax-act.result.json"))
    guard case .result(_, let result) = frame else { Issue.record("expected result"); return }
    let built = AXActResult(
        performed: true,
        matched: AXNode(
            depth: 1, role: "AXButton", subrole: "AXFixtureSubrole",
            title: "Fixture Button", identifier: "fixture-primary-button",
            actions: ["AXPress"],
            frame: ScreenRect(x: 140, y: 520, width: 120, height: 32)
        )
    )
    #expect(built.asObject == result)
}

@Test func decodesInputClickRequest() throws {
    let frame = try JSONRPC.parse(try fixture("input-click.request.json"))
    guard case .request(_, let method, let params) = frame else { Issue.record("expected request"); return }
    #expect(method == "input.click")
    let click = try Messages.inputClick(from: params)
    #expect(click.pid == 4242)
    #expect(click.point == ScreenPoint(x: 512, y: 384))
    #expect(click.button == .left)
    #expect(click.clickCount == 2)
    #expect(click.modifiers == [.shift])
}

@Test func decodesInputClickResult() throws {
    let frame = try JSONRPC.parse(try fixture("input-click.result.json"))
    guard case .result(_, let result) = frame else { Issue.record("expected result"); return }
    // The refusal posture input.key froze in v0: nothing posts without a lease.
    #expect(InputClickResult(posted: false, dryRun: true).asObject == result)
}

@Test func decodesScreenObserveRequest() throws {
    let frame = try JSONRPC.parse(try fixture("screen-observe.request.json"))
    guard case .request(_, let method, let params) = frame else { Issue.record("expected request"); return }
    #expect(method == "screen.observe")
    let observe = try Messages.screenObserve(from: params)
    #expect(observe.region == .rect)
    #expect(observe.rect == ScreenRect(x: 0, y: 0, width: 1440, height: 900))
}

@Test func decodesScreenObserveResult() throws {
    let frame = try JSONRPC.parse(try fixture("screen-observe.result.json"))
    guard case .result(_, let result) = frame else { Issue.record("expected result"); return }
    // Honest while CapturePipeline.captureOnce() is a stub.
    let built = ScreenObserveResult(
        atMs: 1_780_400_000_000,
        frame: ScreenRect(x: 0, y: 0, width: 1440, height: 900),
        imageAvailable: false
    )
    #expect(built.asObject == result)
}

@Test func rejectsMalformedV02Params() {
    #expect(throws: (any Error).self) {
        try Messages.axQuery(from: ["bundleId": .string("x"), "scope": .string("nope"), "maxDepth": .number(2)])
    }
    #expect(throws: (any Error).self) {
        try Messages.inputClick(from: ["pid": .number(1), "point": .object(["x": .number(1)])])
    }
    // region 'rect' without a rect is the one cross-field rule the decoder owns.
    #expect(throws: (any Error).self) {
        try Messages.screenObserve(from: ["region": .string("rect")])
    }
}

/// An N−1 core (min = max = 0.1.0) must still agree with a v0.2 shell. This is the
/// regression the single-element `supported: [ProtocolInfo.version]` list would have
/// caused the moment the version was bumped.
@Test func negotiatesWithAnNMinusOneCore() {
    #expect(ProtocolInfo.supported == ["0.1.0", "0.2.0"])
    #expect(Semver.negotiate(min: "0.1.0", max: "0.1.0", supported: ProtocolInfo.supported) == "0.1.0")
    #expect(
        Semver.negotiate(
            min: ProtocolInfo.minSupported, max: ProtocolInfo.version, supported: ProtocolInfo.supported
        ) == "0.2.0"
    )
    // A future core asking only for 0.3.0 finds no overlap and gets INCOMPATIBLE_PROTOCOL.
    #expect(Semver.negotiate(min: "0.3.0", max: "0.3.0", supported: ProtocolInfo.supported) == nil)
}

@Test func roundTripsResultEncoding() throws {
    let encoded = JSONRPC.encodeResult(id: "c-9", result: ["ok": .bool(true)])
    let frame = try JSONRPC.parse(encoded)
    guard case .result(let id, let result) = frame else { Issue.record("expected result"); return }
    #expect(id == "c-9")
    #expect(result["ok"] == .bool(true))
}
