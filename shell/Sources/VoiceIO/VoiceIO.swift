import Foundation

// Stub. The real plumbing (M0+) owns mic capture, audio playback, and cancellation
// so the core's cascaded VoicePort (STT → LLM → streaming TTS) can achieve <300ms
// barge-in without killing the executor (execution-plan §3.4).
public final class VoiceIO: Sendable {
    public init() {}

    public func startMicrophone() {}
    public func stopMicrophone() {}
    public func cancelPlayback() {}
}
