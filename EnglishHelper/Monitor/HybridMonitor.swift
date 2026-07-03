import Foundation
import AppKit
import Carbon

protocol HybridMonitorDelegate: AnyObject, Sendable {
    func monitorDidStart()
    func monitorDidStop()
    func monitorDidDetectText(_ text: String)
    func monitorShouldAnalyze(_ text: String) async
    func monitorDidEncounterError(_ error: EnglishHelperError)
}

@MainActor
final class HybridMonitor {
    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private let debounce = DebounceManager()
    weak var delegate: HybridMonitorDelegate?
    private var inputBuffer = ""
    private var eventCount = 0
    private var lastWeChatKeystroke = Date.distantPast
    private var lastAwayClear = false
    private var lastCmdCTime = Date.distantPast  // for double-Cmd+C detection
    var isMonitoring: Bool { eventTap != nil }

    /// Check if the current keyboard input source is Chinese
    private func isChineseInputSource() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        guard let lang = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return false }
        let languages = Unmanaged<NSArray>.fromOpaque(lang).takeUnretainedValue() as? [String] ?? []
        return languages.first?.hasPrefix("zh") == true
    }

    func start() throws {
        appendLog("[EH] START monitor\n")

        NotificationCenter.default.addObserver(forName: .suggestionAccepted, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.inputBuffer = ""
                self?.lastAwayClear = false
            }
            appendLog("[EH] BUF CLEAR: suggestion accepted\n")
        }

        NotificationCenter.default.addObserver(forName: .translateClipboard, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.translateFromClipboard()
            }
        }

        // CGEvent.tapCreate needs Input Monitoring permission.
        // The permission dialog only appears for regular (non-accessory) apps in the foreground.
        // Temporarily switch activation policy so macOS can show the dialog if needed.
        let savedPolicy = NSApp.activationPolicy()
        if savedPolicy == .accessory {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        do {
            try createEventTap()
            appendLog("[EH] START tap OK\n")
            delegate?.monitorDidStart()
        } catch {
            appendLog("[EH] START tap FAILED: \(error)\n")
            if savedPolicy == .accessory {
                // Revert to accessory immediately on failure
                NSApp.setActivationPolicy(.accessory)
            }
            throw error
        }

        // Tap created — revert to accessory mode
        if savedPolicy == .accessory {
            // Small delay so the app registers properly before hiding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    func stop() {
        if let t = eventTap { CFMachPortInvalidate(t); eventTap = nil }
        if let s = tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes); tapSource = nil }
        inputBuffer = ""
        Task { await debounce.cancel() }
        delegate?.monitorDidStop()
    }

    private func createEventTap() throws {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    guard type == .keyDown else { return Unmanaged.passUnretained(event) }
                    let kc = event.getIntegerValueField(.keyboardEventKeycode)
                    let fl = event.flags.rawValue
                    var cs = [UniChar](repeating: 0, count: 32); var n = 0
                    event.keyboardGetUnicodeString(maxStringLength: 32, actualStringLength: &n, unicodeString: &cs)
                    let ch = n > 0 ? String(utf16CodeUnits: cs, count: n) : ""
                    let m = Unmanaged<HybridMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                    m.handleRaw(kc: kc, fl: fl, ch: ch)
                    return Unmanaged.passUnretained(event)
                }, userInfo: ctx) else { throw EnglishHelperError.noPermission }
        eventTap = tap
        guard let s = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { throw EnglishHelperError.noPermission }
        tapSource = s
        CFRunLoopAddSource(CFRunLoopGetMain(), s, .commonModes)
    }

    private func handleRaw(kc: Int64, fl: UInt64, ch: String) {
        DispatchQueue.main.async { [self] in
            let flags = CGEventFlags(rawValue: fl)
            let frontApp = NSWorkspace.shared.frontmostApplication
            let frontBundle = frontApp?.bundleIdentifier ?? "?"
            let isWeChat = frontBundle == AppConstants.weChatBundleID

            // ── Hotkey: double Cmd+C — translate selected text ──
            if flags.contains(.maskCommand) && !flags.contains(.maskShift) && !flags.contains(.maskAlternate) && kc == 8 {
                let now = Date()
                let gap = now.timeIntervalSince(self.lastCmdCTime)
                self.lastCmdCTime = now
                if gap < 0.5 && gap > 0.05 {
                    // Prevent triple-tap from triggering twice
                    self.lastCmdCTime = Date.distantPast
                    appendLog("[EH] HOTKEY double Cmd+C gap=\(String(format: "%.2f", gap))s\n")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.translateFromClipboard()
                    }
                }
                return
            }

            // ── In WeChat ──
            guard isWeChat else {
                let away = Date().timeIntervalSince(self.lastWeChatKeystroke)
                if away > 8.0 && !self.inputBuffer.isEmpty {
                    if !self.lastAwayClear {
                        appendLog("[EH] BUF CLEAR: away=\(String(format: "%.0f", away))s\n")
                        self.lastAwayClear = true
                    }
                    self.inputBuffer = ""
                }
                return
            }
            self.lastAwayClear = false
            self.lastWeChatKeystroke = Date()

            // ── Chinese IME active: skip auto-capture, wait for manual hotkey ──
            guard !self.isChineseInputSource() else { return }

            // ── English mode: accumulate and debounce ──
            switch kc {
            case 51: if !self.inputBuffer.isEmpty { self.inputBuffer.removeLast() }
            case 36: if flags.contains(.maskShift) { self.inputBuffer += "\n" } else { self.inputBuffer = "" }
            case 53: self.inputBuffer = ""
            case 123...126: break
            default:
                if !ch.isEmpty, ch.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F }) {
                    self.inputBuffer += ch
                }
            }

            let buf = self.inputBuffer
            self.eventCount += 1
            self.delegate?.monitorDidDetectText(buf)
            NotificationCenter.default.post(name: .keystrokeInWeChat, object: buf)

            Task {
                await self.debounce.schedule(delayNanoseconds: AppConstants.debounceMilliseconds) {
                    let t = buf.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty, t.count >= AppConstants.minTextLength else { return }
                    appendLog("[EH] ANALYZE -> triggerAnalysis(\(t))\n")
                    triggerAnalysis(t)
                }
            }
        }
    }

    /// Translate text from clipboard (after double Cmd+C)
    private func translateFromClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        appendLog("[EH] CLIPBOARD: \(text.prefix(60))\n")

        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, t.count >= AppConstants.minTextLength else {
            appendLog("[EH] CLIPBOARD skip: empty or too short\n")
            return
        }

        let mode = AnalysisEngine.analyzeForTranslate(t)
        guard mode != .skip else {
            appendLog("[EH] CLIPBOARD skip: too short\n")
            return
        }

        appendLog("[EH] CLIPBOARD translate: \(t.prefix(40)) mode=\(mode)\n")
        Task {
            await sharedCoordinator?.processText(t, mode: mode)
        }
    }
}

func appendLog(_ line: String) {
    guard ProcessInfo.processInfo.environment["EH_DEBUG"] == "1" else { return }
    let u = URL(fileURLWithPath: "/tmp/eh.log")
    if let f = try? FileHandle(forWritingTo: u) { f.seekToEndOfFile(); f.write(line.data(using: .utf8)!); try? f.close() }
    else { try? line.data(using: .utf8)?.write(to: u) }
}

extension Notification.Name {
    static let keystrokeInWeChat = Notification.Name("com.typemate.keystrokeInWeChat")
    static let analysisTriggered = Notification.Name("com.typemate.analysisTriggered")
    static let suggestionAccepted = Notification.Name("com.typemate.suggestionAccepted")
    static let translateClipboard = Notification.Name("com.typemate.translateClipboard")
    static let apiKeyUpdated = Notification.Name("com.typemate.apiKeyUpdated")
}
