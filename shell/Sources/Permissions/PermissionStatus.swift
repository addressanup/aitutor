import AVFoundation
import ApplicationServices
import CoreGraphics
import Foundation
import IOKit.hid
import ShellProtocol

// Query-ONLY TCC snapshot — no prompt fires from any call here. The staged,
// value-first prompt flow (execution-plan §4) is separate M0 work.
public enum Permissions {
    public static func snapshot() -> PermissionsStatus {
        PermissionsStatus(
            microphone: microphone(),
            screenRecording: screenRecording(),
            accessibility: accessibility(),
            inputMonitoring: inputMonitoring()
        )
    }

    /// AXIsProcessTrusted does NOT prompt (unlike the WithOptions variant with prompt=true).
    public static func accessibility() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .notDetermined
    }

    /// CGPreflightScreenCaptureAccess is the non-prompting query. Touching
    /// SCShareableContent can trip TCC, so we deliberately avoid it here.
    public static func screenRecording() -> PermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
    }

    public static func inputMonitoring() -> PermissionState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .notDetermined
        }
    }

    public static func microphone() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
}
