import AppKit
import SwiftUI

/// Floating NSPanel for displaying suggestions
@MainActor
final class SuggestionPanelController: NSObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SuggestionView>?
    private var globalEventMonitor: Any?
    private var dismissWorkItem: DispatchWorkItem?
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var currentAutoDismissDelay: TimeInterval = AppConstants.panelAutoDismissSeconds

    func show(suggestion: SuggestionResponse, appState: AppState) {
        dismissWorkItem?.cancel()
        dismiss()

        let dismissDelay = max(appState.settings.autoDismissDelay, 2.0)
        currentAutoDismissDelay = dismissDelay

        let contentView = SuggestionView(
            suggestion: suggestion,
            autoDismissSeconds: Int(dismissDelay),
            onAccept: { [weak self] index in
                self?.onAccept(index: index, suggestion: suggestion, appState: appState)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hosting = NSHostingView(rootView: contentView)

        hosting.layout()
        let idealSize = hosting.fittingSize
        let height = min(max(idealSize.height, 120), 350)
        let width = AppConstants.panelDefaultWidth

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        panel.contentView = hosting
        hostingView = hosting
        self.panel = panel

        setupHoverTracking(panel)
        positionPanel(panel)
        panel.orderFrontRegardless()
        setupGlobalMonitor(suggestion: suggestion, appState: appState)
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()
        let delay = currentAutoDismissDelay
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isHovering else {
                self.scheduleAutoDismiss()
                return
            }
            self.dismiss()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func setupHoverTracking(_ panel: NSPanel) {
        guard let contentView = panel.contentView else { return }
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    @objc func mouseEntered(_ event: NSEvent) {
        isHovering = true
        dismissWorkItem?.cancel()
    }

    @objc func mouseExited(_ event: NSEvent) {
        isHovering = false
        scheduleAutoDismiss()
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        panel?.close()
        panel = nil
        hostingView = nil
        if let m = globalEventMonitor {
            NSEvent.removeMonitor(m)
            globalEventMonitor = nil
        }
    }

    // MARK: - Positioning

    private func positionPanel(_ panel: NSPanel) {
        if let wechatFrame = getWeChatWindowFrame(),
           let screen = screenContaining(wechatFrame) ?? NSScreen.main {
            let vis = screen.visibleFrame
            let pw = panel.frame.width
            let ph = panel.frame.height

            let rightSpace = vis.maxX - wechatFrame.maxX
            let x: CGFloat = rightSpace >= pw + 8
                ? wechatFrame.maxX
                : wechatFrame.minX - pw

            let y = min(max(wechatFrame.midY - ph / 2, vis.minY + 8), vis.maxY - ph - 8)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.midX - panel.frame.width / 2
            let y = frame.midY - panel.frame.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func screenContaining(_ rect: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.intersects(rect) }
    }

    private func getWeChatWindowFrame() -> NSRect? {
        guard let wechatApp = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == AppConstants.weChatBundleID }) else { return nil }
        let pid = wechatApp.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let wechatWindow = windowList.first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid }),
              let bounds = wechatWindow[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"],
              let w = bounds["Width"], let h = bounds["Height"] else { return nil }
        return NSRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Global Event Monitor

    private func setupGlobalMonitor(suggestion: SuggestionResponse, appState: AppState) {
        if let existing = globalEventMonitor {
            NSEvent.removeMonitor(existing)
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags
            let keyCode = event.keyCode
            Task { @MainActor [weak self] in
                guard let self, self.panel != nil else { return }
                // Use Option+1/2/3 to avoid conflict with WeChat's Cmd+1-9 tab switching
                if flags.contains(.option) && !flags.contains(.command) {
                    let keyMap: [UInt16: Int] = [18: 0, 19: 1, 20: 2]
                    if let index = keyMap[keyCode] {
                        self.onAccept(index: index, suggestion: suggestion, appState: appState)
                    }
                }
                if keyCode == 53 {
                    self.dismiss()
                }
            }
        }
    }

    // MARK: - Accept

    private func onAccept(index: Int, suggestion: SuggestionResponse, appState: AppState) {
        let text = index == 0 ? suggestion.primarySuggestion
            : index <= suggestion.alternatives.count ? suggestion.alternatives[index - 1]
            : suggestion.primarySuggestion

        guard let pid = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == AppConstants.weChatBundleID })?.processIdentifier else { return }

        if !TextReplacer.replaceViaAX(pid: pid, newText: text) {
            TextReplacer.replaceViaClipboard(newText: text)
        }
        NotificationCenter.default.post(name: .suggestionAccepted, object: nil)
        dismiss()
        appState.resetPipeline()
    }
}
