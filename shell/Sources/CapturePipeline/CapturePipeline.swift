import Foundation

// Stub. The real pipeline (M0+) uses ScreenCaptureKit with an SCContentFilter that
// EXCLUDES the shell's own overlay windows (execution-plan §2), per-window capture
// at low fps, and SCScreenshotManager one-shots. The overlay's CGWindowID registry
// (see Overlay) feeds the exclusion list.
public final class CapturePipeline: Sendable {
    public init() {}

    /// The exclusion contract exists now so the overlay never contaminates a frame.
    public func setExcludedWindowIDs(_ ids: [UInt32]) {
        _ = ids
        // Future: rebuild SCContentFilter(excludingWindows:) with these IDs.
    }

    public func captureOnce() async throws {
        // Future: SCScreenshotManager.captureImage(contentFilter:configuration:)
    }
}
