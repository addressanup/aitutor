import AppKit
import ShellProtocol

// MainActor controller for the spotlight overlay. Owns the panel, converts wire
// coordinates (top-left screen points) into the panel's flipped view space, and
// keeps a CGWindowID registry so CapturePipeline can exclude the overlay from
// capture (execution-plan §2).
@MainActor
public final class OverlayController {
    private var panel: OverlayPanel?
    private var view: SpotlightView?
    private var clearTask: Task<Void, Never>?

    public init() {}

    /// CGWindowIDs of every overlay surface — the capture-exclusion list.
    public var windowIDs: [UInt32] {
        guard let panel else { return [] }
        return [UInt32(panel.windowNumber)]
    }

    public func drawSpotlights(_ spots: [OverlaySpotlight], ttlMs: Int?) -> Int {
        guard let screen = NSScreen.main else { return 0 }
        ensurePanel(on: screen)
        guard let view else { return 0 }

        // Wire is top-left origin; the SpotlightView is flipped (also top-left),
        // so within the full-screen panel the rects map directly.
        let rects = spots.map { NSRect(x: $0.rect.x, y: $0.rect.y, width: $0.rect.width, height: $0.rect.height) }
        let caption = spots.first?.caption
        view.show(rects: rects, caption: caption)
        panel?.orderFrontRegardless()

        clearTask?.cancel()
        if let ttlMs {
            clearTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(ttlMs))
                if !Task.isCancelled { self?.clear() }
            }
        }
        return spots.count
    }

    public func clear() {
        clearTask?.cancel()
        clearTask = nil
        view?.clear()
        panel?.orderOut(nil)
    }

    private func ensurePanel(on screen: NSScreen) {
        if panel != nil { return }
        let p = OverlayPanel(screenFrame: screen.frame)
        let v = SpotlightView(frame: NSRect(origin: .zero, size: screen.frame.size))
        p.contentView = v
        panel = p
        view = v
    }
}
