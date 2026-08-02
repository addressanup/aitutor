import AppKit
import SwiftUI

// Menu-bar-only app (LSUIElement in Info.plist; .accessory as a fallback for
// unbundled `swift run`). An AppDelegate starts the IPC server + organs at launch
// — NOT from the menu's onAppear, which only fires when the user opens the menu.
@main
struct TutorShellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Tutor", systemImage: "graduationcap") {
            MenuContentView(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
