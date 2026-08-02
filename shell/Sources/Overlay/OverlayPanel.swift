import AppKit

// The click-through telestration panel. The retrofit-expensive fundamentals are all
// here at creation (execution-plan §2, §3.1): screen-saver level (draws above other
// apps incl. fullscreen), click-through, clear background, and sharingType = .none so
// the panel is EXCLUDED from screen capture — screenshots show the learner's screen
// as if the tutor weren't drawing on it.
final class OverlayPanel: NSPanel {
    init(screenFrame: NSRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        // Exclude this panel from ScreenCaptureKit capture.
        sharingType = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
