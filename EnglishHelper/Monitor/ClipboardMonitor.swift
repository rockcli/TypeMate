import Foundation
import AppKit

/// Zero-permission monitor: watches clipboard changes when WeChat is frontmost
@MainActor
final class ClipboardMonitor {
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let debounce = DebounceManager()
    weak var delegate: HybridMonitorDelegate?

    var isMonitoring: Bool { timer != nil }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.check() }
        }
        delegate?.monitorDidStart()
    }

    func stop() {
        timer?.invalidate(); timer = nil
        Task { await debounce.cancel() }
        delegate?.monitorDidStop()
    }

    private func check() async {
        let board = NSPasteboard.general
        guard board.changeCount != lastChangeCount else { return }
        lastChangeCount = board.changeCount

        // Only process when WeChat is frontmost
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == AppConstants.weChatBundleID,
              let text = board.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, text.count >= AppConstants.minTextLength else { return }

        delegate?.monitorDidDetectText(text)
        await debounce.schedule {
            await self.delegate?.monitorShouldAnalyze(text)
        }
    }
}
