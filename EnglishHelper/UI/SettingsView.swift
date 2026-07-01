import SwiftUI

/// Settings window
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var enableTranslation: Bool = true
    @State private var enableImprovement: Bool = true
    @State private var debounceMs: Double = 300
    @State private var autoDismissSec: Double = 5.0
    @State private var showKeySaved: Bool = false
    @State private var showConnectionTest: String = ""

    var body: some View {
        TabView {
            // General
            Form {
                Toggle("Chinese → English Translation", isOn: $enableTranslation)
                Toggle("English Improvement", isOn: $enableImprovement)

                Divider()

                HStack {
                    Text("Debounce (ms):")
                    Slider(value: $debounceMs, in: 100...1000, step: 50)
                    Text("\(Int(debounceMs))")
                        .fontDesign(.monospaced)
                        .frame(width: 40)
                }

                HStack {
                    Text("Auto-dismiss (s):")
                    Slider(value: $autoDismissSec, in: 2...15, step: 1)
                    Text("\(Int(autoDismissSec))")
                        .fontDesign(.monospaced)
                        .frame(width: 30)
                }
            }
            .tabItem { Label("General", systemImage: "gear") }
            .padding()
            .onChange(of: enableTranslation) { save() }
            .onChange(of: enableImprovement) { save() }
            .onChange(of: debounceMs) { save() }
            .onChange(of: autoDismissSec) { save() }

            // API
            Form {
                Section("DeepSeek API Key") {
                    SecureField("sk-...", text: $apiKey)
                        .onSubmit { saveAPIKey() }

                    Button("Save") { saveAPIKey() }
                        .disabled(apiKey.isEmpty)

                    if showKeySaved {
                        Text("✅ Saved")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    if !showConnectionTest.isEmpty {
                        Text(showConnectionTest)
                            .font(.caption)
                    }
                }

                Section {
                    Text("API key is stored securely in Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("You can also set ANTHROPIC_API_KEY in ~/.zshrc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tabItem { Label("API", systemImage: "key") }
            .padding()

            // About
            VStack(spacing: 16) {
                Image(systemName: "character.text.justify")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                Text("TypeMate")
                    .font(.title)
                Text("Real-time English writing assistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Version 1.0")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))

                Divider()
                    .frame(width: 200)

                Text("Personal use only. Not for distribution.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .tabItem { Label("About", systemImage: "info.circle") }
            .padding()
        }
        .frame(width: 450, height: 400)
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
    }

    private func save() {
        var s = appState.settings
        s.enableTranslation = enableTranslation
        s.enableImprovement = enableImprovement
        s.debounceMilliseconds = Int(debounceMs)
        s.autoDismissDelay = autoDismissSec
        ConfigurationManager.saveSettings(s)
        appState.settings = s
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }
        try? ConfigurationManager.saveAPIKey(apiKey)
        showKeySaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showKeySaved = false
        }
    }
}
