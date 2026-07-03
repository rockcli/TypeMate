import AppKit
import SwiftUI

/// NSStatusBar menu bar controller
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let appState: AppState
    private var settingsWindow: NSWindow?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupMenuBar()
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "character.text.justify",
                accessibilityDescription: "EnglishHelper"
            )
            button.image?.isTemplate = true
        }

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        // Status indicator
        let statusTitle: String
        switch appState.monitoringStatus {
        case .monitoring:
            statusTitle = "● Monitoring"
        case .notMonitoring:
            statusTitle = "○ Paused"
        case .unavailable:
            statusTitle = "◇ WeChat not running"
        case .noPermission:
            statusTitle = "⚠ Permission needed"
        }
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Toggle
        let toggleTitle = appState.monitoringStatus == .monitoring ? "Pause Monitoring" : "Start Monitoring"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring), keyEquivalent: "t")
        toggleItem.isEnabled = (appState.monitoringStatus != .unavailable)
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Menu Delegate

    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    // MARK: - Actions

    @objc private func toggleMonitoring() {
        if appState.monitoringStatus == .monitoring {
            NotificationCenter.default.post(name: .stopMonitoring, object: nil)
        } else {
            NotificationCenter.default.post(name: .startMonitoring, object: nil)
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(appState: appState)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "EnglishHelper Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 450, height: 400))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let startMonitoring = Notification.Name("com.typemate.startMonitoring")
    static let stopMonitoring = Notification.Name("com.typemate.stopMonitoring")
}
