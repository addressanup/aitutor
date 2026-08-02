import AppKit

// Even-odd dim-with-cutout spotlight, plus an optional caption banner. The only
// overlay primitives at scaffold are spotlight + clear (execution-plan overbuild
// rule); the full 8-primitive language is later work.
final class SpotlightView: NSView {
    private var cutouts: [NSRect] = []
    private var caption: String?

    override var isFlipped: Bool { true } // top-left origin, matching the wire convention

    func show(rects: [NSRect], caption: String?) {
        self.cutouts = rects
        self.caption = caption
        needsDisplay = true
    }

    func clear() {
        cutouts = []
        caption = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !cutouts.isEmpty else { return }
        let dim = NSBezierPath(rect: bounds)
        for r in cutouts { dim.appendRect(r) }
        dim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.35).setFill()
        dim.fill()

        let accent = NSColor(calibratedRed: 0.66, green: 0.45, blue: 0.06, alpha: 1)
        accent.setStroke()
        for r in cutouts {
            let stroke = NSBezierPath(rect: r.insetBy(dx: -1, dy: -1))
            stroke.lineWidth = 2
            stroke.stroke()
        }

        if let caption, let first = cutouts.first {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let size = (caption as NSString).size(withAttributes: attrs)
            let pad: CGFloat = 8
            let bx = first.minX
            let by = max(0, first.minY - size.height - 2 * pad - 6)
            let bg = NSRect(x: bx, y: by, width: size.width + 2 * pad, height: size.height + 2 * pad)
            NSColor.black.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: bg, xRadius: 6, yRadius: 6).fill()
            (caption as NSString).draw(at: NSPoint(x: bx + pad, y: by + pad), withAttributes: attrs)
        }
    }
}
