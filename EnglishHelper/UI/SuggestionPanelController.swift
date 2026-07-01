import AppKit
import SwiftUI

/// Floating NSPanel for displaying suggestions
/// Fixes: no flicker (updates existing panel), longer timeout, extends on hover
@MainActor
final class SuggestionPanelController: NSObject {
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SuggestionView>?
    private var globalEventMonitor: Any?
    private var dismissWorkItem: DispatchWorkItem?
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    func show(suggestion: SuggestionResponse, appState: AppState) {
        // Cancel pending dismiss
        dismissWorkItem?.cancel()

        // Always recreate panel to avoid stale state
        // (rootView assignment on existing NSHostingView is unreliable in newer SwiftUI)
        dismiss()

        let contentView = SuggestionView(
            suggestion: suggestion,
            onAccept: { [weak self] index in
                self?.onAccept(index: index, suggestion: suggestion, appState: appState)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        let hosting = NSHostingView(rootView: contentView)

        // Let SwiftUI layout first, then measure ideal size
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

        // Mouse tracking: pause auto-dismiss while hovering
        setupHoverTracking(panel)

        // Position and animate
        positionPanel(panel)
        panel.orderFrontRegardless()

        // Global event monitor for keyboard shortcuts
        setupGlobalMonitor(suggestion: suggestion, appState: appState)

        // Auto-dismiss after 10 seconds (paused while hovering)
        scheduleAutoDismiss()
    }

    private func scheduleAutoDismiss() {
        dismissWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isHovering else {
                self.scheduleAutoDismiss()
                return
            }
            self.dismiss()
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
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
        // Cancel auto-dismiss while hovering
        dismissWorkItem?.cancel()
    }

    @objc func mouseExited(_ event: NSEvent) {
        isHovering = false
        // Restart auto-dismiss countdown
        scheduleAutoDismiss()
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        panel?.close()
        panel = nil
        hostingView = nil
        if let m = globalEventMonitor { NSEvent.removeMonitor(m); globalEventMonitor = nil }
    }

    // MARK: - Positioning

    private func positionPanel(_ panel: NSPanel) {
        // Try to position near WeChat window
        if let wechatFrame = getWeChatWindowFrame(),
           let screen = screenContaining(wechatFrame) ?? NSScreen.main {
            let vis = screen.visibleFrame
            let pw = panel.frame.width
            let ph = panel.frame.height

            // Prefer right side, flip to left if not enough space
            let rightSpace = vis.maxX - wechatFrame.maxX
            let x: CGFloat = rightSpace >= pw + 8
                ? wechatFrame.maxX                    // Right side, flush left-to-right
                : wechatFrame.minX - pw               // Left side, flush right-to-left

            let y = min(max(wechatFrame.midY - ph / 2, vis.minY + 8), vis.maxY - ph - 8)

            panel.setFrameOrigin(NSPoint(x: x, y: y))
            return
        }

        // Fallback: center on main screen
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

    private func clampToScreen(_ rect: NSRect, screen: NSScreen) -> NSRect {
        let vis = screen.visibleFrame
        var r = rect
        r.origin.x = max(vis.minX + 8, min(r.origin.x, vis.maxX - r.width - 8))
        r.origin.y = max(vis.minY + 8, min(r.origin.y, vis.maxY - r.height - 8))
        return r
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
        if globalEventMonitor != nil { NSEvent.removeMonitor(globalEventMonitor!) }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.panel != nil else { return }
            // Use Option+1/2/3 to avoid conflict with WeChat's Cmd+1-9 tab switching
            if event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.command) {
                let keyMap: [UInt16: Int] = [18: 0, 19: 1, 20: 2]
                if let index = keyMap[event.keyCode] {
                    self?.onAccept(index: index, suggestion: suggestion, appState: appState)
                }
            }
            if event.keyCode == 53 { self?.dismiss() }
        }
    }

    // MARK: - Accept

    private func onAccept(index: Int, suggestion: SuggestionResponse, appState: AppState) {
        let text = index == 0 ? suggestion.primarySuggestion
            : index <= suggestion.alternatives.count ? suggestion.alternatives[index - 1]
            : suggestion.primarySuggestion

        guard let pid = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == AppConstants.weChatBundleID })?.processIdentifier else { return }

        if TextReplacer.replaceViaAX(pid: pid, newText: text) {} else {
            TextReplacer.replaceViaClipboard(newText: text)
        }
        NotificationCenter.default.post(name: .suggestionAccepted, object: nil)
        dismiss()
        appState.resetPipeline()
    }
}
