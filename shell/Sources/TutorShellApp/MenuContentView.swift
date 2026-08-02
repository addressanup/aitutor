import ShellProtocol
import SwiftUI

struct MenuContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tutor").font(.headline)
            Text(model.serverRunning ? "IPC listening on 127.0.0.1:\(model.port)" : "IPC not running")
                .font(.caption)
                .foregroundStyle(model.serverRunning ? Color.secondary : Color.red)

            Divider()

            permissionRow("Microphone", model.permissions.microphone)
            permissionRow("Screen Recording", model.permissions.screenRecording)
            permissionRow("Accessibility", model.permissions.accessibility)
            permissionRow("Input Monitoring", model.permissions.inputMonitoring)

            Divider()
            Button("Refresh permissions") { model.refreshPermissions() }
            Button("Quit Tutor") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func permissionRow(_ label: String, _ state: PermissionState) -> some View {
        HStack {
            Circle().fill(color(for: state)).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            Text(text(for: state)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func color(for state: PermissionState) -> Color {
        switch state {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .yellow
        }
    }

    private func text(for state: PermissionState) -> String {
        switch state {
        case .granted: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "not set"
        }
    }
}
