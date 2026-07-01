import AppKit
import SwiftUI

@main
struct EnglishHelperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("📝", systemImage: "pencil.and.outline") {
            VStack(alignment: .leading, spacing: 6) {
                Text("TypeMate")
                    .font(.system(size: 10, weight: .bold))
                Text("Real-time English writing assistant · Powered by Rock")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Divider()
                Button("Translate Selection  ⌘C×2") {
                    NotificationCenter.default.post(name: .translateClipboard, object: nil)
                }
                Divider()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(10)
            .frame(minWidth: 220)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: PipelineCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let c = PipelineCoordinator()
        coordinator = c
        Task { @MainActor in await c.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
