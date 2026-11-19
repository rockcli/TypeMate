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
    private var settingsWindow: NSWindow?
    private var lastAnalyzedText = ""
    private var lastLLMCall = Date.distantPast

    func start() async {
        appState.settings = ConfigurationManager.loadSettings()
        setupLLMService()
        monitor.delegate = self
        sharedCoordinator = self

        // Re-initialize LLM service when API key or endpoint/model settings change
        NotificationCenter.default.addObserver(forName: .apiKeyUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setupLLMService()
            }
        }
        NotificationCenter.default.addObserver(forName: .settingsUpdated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setupLLMService()
            }
        }

        await autoStartIfPossible()
    }

    func stop() { monitor.stop(); appState.resetPipeline() }

    func openSettings() {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(appState: appState)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "TypeMate Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 480, height: 430))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func setupLLMService() {
        guard let key = ConfigurationManager.getAPIKey() else {
            llmService = nil
            appendLog("[TypeMate] NO API KEY\n")
            return
        }
        let settings = appState.settings
        let baseURL = settings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveURL = baseURL.isEmpty
            ? (ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"] ?? AppConstants.deepSeekBaseURL)
            : baseURL
        let model = settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveModel = model.isEmpty ? AppConstants.deepSeekModel : model

        appendLog("[TypeMate] LLM ready: model=\(effectiveModel), baseURL=\(effectiveURL)\n")
        llmService = LLMService(apiKey: key, baseURL: effectiveURL, model: effectiveModel)
    }

    private func autoStartIfPossible() async {
        let wxRunning = NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == AppConstants.weChatBundleID })
        appendLog("[TypeMate] autoStart: wxRunning=\(wxRunning)\n")
        guard wxRunning else { appState.monitoringStatus = .unavailable; return }
        do { try monitor.start() }
        catch { appendLog("[TypeMate] autoStart ERROR: \(error)\n"); appState.monitoringStatus = .noPermission }
    }

    // Auto-detect mode: English buffered input or explicit manual translation
    nonisolated func processText(_ text: String, mode: AnalysisMode? = nil) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= AppConstants.minTextLength else {
            appendLog("[TypeMate] PROC skip short: \(t)\n")
            return
        }

        let detectedMode = mode ?? AnalysisEngine.analyze(t)
        guard detectedMode != .skip else {
            appendLog("[TypeMate] PROC skip mode\n")
            return
        }

        let settings = await MainActor.run { self.appState.settings }
        switch detectedMode {
        case .chineseToEnglish, .englishToChinese:
            guard settings.enableTranslation else { return }
        case .englishImprovement:
            guard settings.enableImprovement else { return }
        case .skip:
            return
        }

        // Dedup only for auto mode (no explicit mode) — allow re-translation on manual trigger
        if mode == nil {
            let lastCheck = await MainActor.run { self.lastAnalyzedText }
            guard t != lastCheck else {
                appendLog("[TypeMate] PROC skip dup\n")
                return
            }
        }

        // Rate limit: throttle identical text within 1s
        let cooldown = await MainActor.run { Date().timeIntervalSince(self.lastLLMCall) }
        let sameAsLast = t == (await MainActor.run { self.lastAnalyzedText })
        if sameAsLast && cooldown < 1.0 {
            appendLog("[TypeMate] PROC cooldown skip: \(String(format: "%.1f", cooldown))s\n")
            return
        }
        await MainActor.run { self.lastLLMCall = Date() }

        let bounded = String(t.prefix(AppConstants.maxBufferSize))

        if let cached = await cache.get(text: bounded, mode: detectedMode) {
            let cachedResponse = SuggestionResponse(
                primarySuggestion: cached.primarySuggestion,
                alternatives: cached.alternatives,
                mode: cached.mode,
                latency: 0,
                source: .cache,
                timestamp: Date()
            )
            await MainActor.run {
                self.lastAnalyzedText = t
                self.showSuggestion(cachedResponse)
            }
            appendLog("[TypeMate] PROC cache hit mode=\(detectedMode)\n")
            return
        }

        appendLog("[TypeMate] PROC call LLM mode=\(detectedMode)\n")
        let llm = await MainActor.run { self.llmService }
        guard let llm = llm else {
            appendLog("[TypeMate] PROC FAIL no llmService\n")
            return
        }

        do {
            let r = try await llm.suggest(for: bounded, mode: detectedMode)
            await cache.set(text: bounded, mode: detectedMode, response: r)
            await MainActor.run {
                self.lastAnalyzedText = t
                self.showSuggestion(r)
            }
            appendLog("[TypeMate] PROC LLM OK: \(r.primarySuggestion.prefix(50))\n")
        } catch {
            appendLog("[TypeMate] PROC LLM ERR: \(error)\n")
        }
    }

    private func showSuggestion(_ r: SuggestionResponse) {
        appState.currentSuggestion = r
        appState.suggestionState = .showing(r)
        panelController.show(suggestion: r, appState: appState)
        appState.isPanelVisible = true
        appendLog("[TypeMate] PANEL shown\n")
    }
}

// Direct call from Monitor
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
        appendLog("[TypeMate] DEL SHOULD ANALYZE: \(text)\n")
        await processText(text)
    }
    nonisolated func monitorDidEncounterError(_ e: TypeMateError) {}
}
