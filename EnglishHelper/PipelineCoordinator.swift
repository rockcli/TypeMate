import Foundation
import AppKit
import SwiftUI

/// Shared instance for direct access from Monitor callback
@MainActor var sharedCoordinator: PipelineCoordinator?

@MainActor
final class PipelineCoordinator: @unchecked Sendable, ObservableObject {
    let appState = AppState()
    private let monitor = HybridMonitor()
    private var llmService: LLMService?
    private let cache = SuggestionCache()
    private let panelController = SuggestionPanelController()
    private var lastAnalyzedText = ""
    private var lastLLMCall = Date.distantPast

    func start() async {
        appState.settings = ConfigurationManager.loadSettings()
        setupLLMService()
        monitor.delegate = self
        sharedCoordinator = self
        await autoStartIfPossible()
    }

    func stop() { monitor.stop(); appState.resetPipeline() }

    func openSettings() {
        let view = SettingsView(appState: appState)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "TypeMate Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 450, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupLLMService() {
        guard let key = ConfigurationManager.getAPIKey() else {
            appendLog("[EH] NO API KEY!\n")
            return
        }
        appendLog("[EH] API key OK: \(key.prefix(10))...\n")
        llmService = LLMService(apiKey: key, baseURL: appState.settings.baseURL, model: appState.settings.modelName)
    }

    private func autoStartIfPossible() async {
        let wxRunning = NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == AppConstants.weChatBundleID })
        appendLog("[EH] autoStart: wxRunning=\(wxRunning)\n")
        guard wxRunning else { appState.monitoringStatus = .unavailable; return }
        do { try monitor.start() }
        catch { appendLog("[EH] autoStart ERROR: \(error)\n"); appState.monitoringStatus = .noPermission }
    }

    // Auto-detect mode: English buffered input
    nonisolated func processText(_ text: String, mode: AnalysisMode? = nil) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= AppConstants.minTextLength else {
            appendLog("[EH] PROC skip short: \(t)\n")
            return
        }

        let detectedMode = mode ?? AnalysisEngine.analyze(t)
        guard detectedMode != .skip else { appendLog("[EH] PROC skip mode\n"); return }

        // Dedup only for auto mode (no explicit mode) — allow re-translation on manual trigger
        if mode == nil {
            let lastCheck = await MainActor.run { self.lastAnalyzedText }
            guard t != lastCheck else { appendLog("[EH] PROC skip dup\n"); return }
        }

        // Rate limit: only throttle same text within 1s
        let cooldown = await MainActor.run { Date().timeIntervalSince(self.lastLLMCall) }
        let sameAsLast = t == (await MainActor.run { self.lastAnalyzedText })
        if sameAsLast && cooldown < 1.0 {
            appendLog("[EH] PROC cooldown skip: same text, \(String(format: "%.1f", cooldown))s\n")
            return
        }
        await MainActor.run { self.lastLLMCall = Date() }

        let bounded = String(t.prefix(AppConstants.maxBufferSize))
        appendLog("[EH] PROC call LLM mode=\(detectedMode) t=\(bounded)\n")

        let llm = await MainActor.run { self.llmService }
        guard let llm = llm else {
            appendLog("[EH] PROC FAIL no llmService\n")
            return
        }

        do {
            let r = try await llm.suggest(for: bounded, mode: detectedMode)
            await MainActor.run {
                self.lastAnalyzedText = t
                self.showSuggestion(r)
            }
            appendLog("[EH] PROC LLM OK: \(r.primarySuggestion.prefix(50))\n")
        } catch {
            appendLog("[EH] PROC LLM ERR: \(error)\n")
        }
    }

    private func showSuggestion(_ r: SuggestionResponse) {
        appState.currentSuggestion = r
        appState.suggestionState = .showing(r)
        panelController.show(suggestion: r, appState: appState)
        appState.isPanelVisible = true
        appendLog("[EH] PANEL shown!\n")
    }
}

// Direct call from Monitor — bypasses delegate/notification entirely
func triggerAnalysis(_ text: String) {
    Task {
        await sharedCoordinator?.processText(text)
    }
}

extension PipelineCoordinator: HybridMonitorDelegate {
    nonisolated func monitorDidStart() { Task { @MainActor in sharedCoordinator?.appState.monitoringStatus = .monitoring } }
    nonisolated func monitorDidStop() { Task { @MainActor in sharedCoordinator?.appState.monitoringStatus = .notMonitoring } }
    nonisolated func monitorDidDetectText(_ text: String) { Task { @MainActor in sharedCoordinator?.appState.inputBuffer = text } }
    nonisolated func monitorShouldAnalyze(_ text: String) async {
        appendLog("[EH] DEL SHOULD ANALYZE: \(text)\n")
        await processText(text)
    }
    nonisolated func monitorDidEncounterError(_ e: EnglishHelperError) {}
}
