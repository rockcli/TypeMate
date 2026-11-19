import SwiftUI

/// Settings window
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var baseURL: String = AppConstants.deepSeekBaseURL
    @State private var modelName: String = AppConstants.deepSeekModel
    @State private var enableTranslation: Bool = true
    @State private var enableImprovement: Bool = true
    @State private var debounceMs: Double = 300
    @State private var autoDismissSec: Double = AppConstants.panelAutoDismissSeconds
    @State private var showSavedBanner: Bool = false

    var body: some View {
        TabView {
            // General
            Form {
                Toggle("Chinese ↔ English Translation (⌘C×2)", isOn: $enableTranslation)
                Toggle("English Auto-Improvement in WeChat", isOn: $enableImprovement)

                Divider()

                HStack {
                    Text("Debounce (ms):")
                    Slider(value: $debounceMs, in: 100...1000, step: 50)
                    Text("\(Int(debounceMs))")
                        .fontDesign(.monospaced)
                        .frame(width: 44, alignment: .trailing)
                }

                HStack {
                    Text("Auto-dismiss (s):")
                    Slider(value: $autoDismissSec, in: 2...20, step: 1)
                    Text("\(Int(autoDismissSec))")
                        .fontDesign(.monospaced)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            .tabItem { Label("General", systemImage: "gear") }
            .padding()
            .onChange(of: enableTranslation) { saveGeneral() }
            .onChange(of: enableImprovement) { saveGeneral() }
            .onChange(of: debounceMs) { saveGeneral() }
            .onChange(of: autoDismissSec) { saveGeneral() }

            // API
            Form {
                Section("Endpoint & Model (Anthropic-compatible)") {
                    TextField("Base URL", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    TextField("Model ID", text: $modelName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    HStack(spacing: 8) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(AppConstants.deepSeekModels, id: \.self) { preset in
                            Button(preset) {
                                modelName = preset
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Spacer()
                        Button("Reset") {
                            baseURL = AppConstants.deepSeekBaseURL
                            modelName = AppConstants.deepSeekModel
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }

                Section("API Key") {
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveAPIConfig() }

                    HStack {
                        Button("Save & Apply") { saveAPIConfig() }
                            .buttonStyle(.borderedProminent)

                        if showSavedBanner {
                            Text("✓ Saved & applied")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }

                Section {
                    Text("Key is stored securely in macOS Keychain (com.typemate).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Env vars ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN also work.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tabItem { Label("API", systemImage: "key") }
            .padding()

            // About
            VStack(spacing: 14) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
                Text("TypeMate")
                    .font(.title2.bold())
                Text("Real-time macOS English writing assistant & instant translator")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Text("Version 1.0.0")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.8))

                Divider()
                    .frame(width: 220)

                Text("Open Source · MIT License")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .tabItem { Label("About", systemImage: "info.circle") }
            .padding()
        }
        .frame(width: 480, height: 430)
        .onAppear {
            loadSettings()
            apiKey = ConfigurationManager.getAPIKey() ?? ""
        }
    }

    private func loadSettings() {
        let s = appState.settings
        enableTranslation = s.enableTranslation
        enableImprovement = s.enableImprovement
        debounceMs = Double(s.debounceMilliseconds)
        autoDismissSec = s.autoDismissDelay
        baseURL = s.baseURL
        modelName = s.modelName
    }

    private func saveGeneral() {
        var s = appState.settings
        s.enableTranslation = enableTranslation
        s.enableImprovement = enableImprovement
        s.debounceMilliseconds = Int(debounceMs)
        s.autoDismissDelay = autoDismissSec
        ConfigurationManager.saveSettings(s)
        appState.settings = s
    }

    private func saveAPIConfig() {
        var s = appState.settings
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        s.baseURL = trimmedURL.isEmpty ? AppConstants.deepSeekBaseURL : trimmedURL
        s.modelName = trimmedModel.isEmpty ? AppConstants.deepSeekModel : trimmedModel
        baseURL = s.baseURL
        modelName = s.modelName

        ConfigurationManager.saveSettings(s)
        appState.settings = s

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            try? ConfigurationManager.saveAPIKey(trimmedKey)
            NotificationCenter.default.post(name: .apiKeyUpdated, object: nil)
        }
        NotificationCenter.default.post(name: .settingsUpdated, object: nil)

        showSavedBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedBanner = false
        }
    }
}
