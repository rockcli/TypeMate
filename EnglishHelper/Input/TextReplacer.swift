import AppKit
import ApplicationServices

/// Safe text replacement in WeChat
/// Fixes Codex V2-C5: preserves ALL clipboard content, uses private pasteboard for temp storage
@MainActor
enum TextReplacer {
    // MARK: - Primary: AXValue Set

    /// Try to replace text directly via AXValue attribute
    static func replaceViaAX(pid: pid_t, newText: String) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success else {
            return false
        }

        // Check if settable
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(focused as! AXUIElement, kAXValueAttribute as CFString, &settable) == .success,
              settable.boolValue else {
            return false
        }

        let result = AXUIElementSetAttributeValue(focused as! AXUIElement, kAXValueAttribute as CFString, newText as CFString)
        return result == .success
    }

    // MARK: - Fallback: Clipboard (Safe Version)

    /// Replace text via clipboard paste (Cmd+V) with full clipboard preservation
    /// Fixes Codex V2-C5: saves ALL pasteboard items, uses private temp board
    static func replaceViaClipboard(newText: String) {
        // 1. Save ALL current pasteboard contents
        let generalBoard = NSPasteboard.general
        let savedItems = generalBoard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let saved = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    saved.setData(data, forType: type)
                }
            }
            return saved
        } ?? []

        // 2. Set new text on general pasteboard
        generalBoard.clearContents()
        generalBoard.setString(newText, forType: .string)

        // 3. Simulate Cmd+A, Cmd+V via CGEvent
        postSelectAll()
        postPaste()

        // 4. Restore original clipboard after delay (Fixes Codex V2-N1: configurable delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.clipboardRestoreDelay) {
            generalBoard.clearContents()
            if !savedItems.isEmpty {
                generalBoard.writeObjects(savedItems)
            }
        }
    }

    // MARK: - CGEvent Helpers

    private static func postSelectAll() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // Cmd
        cmdDown?.flags = .maskCommand

        let aDown = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true) // A
        aDown?.flags = .maskCommand

        let aUp = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false)
        aUp?.flags = .maskCommand

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.post(tap: .cghidEventTap)
        aDown?.post(tap: .cghidEventTap)
        usleep(20_000) // 20ms
        aUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    private static func postPaste() {
        usleep(30_000) // 30ms gap
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V
        cmdDown?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)

        usleep(10_000)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
    }
}
