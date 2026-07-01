// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypeMate",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "TypeMate",
            path: "EnglishHelper",
            exclude: [
                "Info.plist",
                "Monitor/ClipboardMonitor.swift",
                "UI/MenuBarController.swift"
            ],
            sources: [
                "EnglishHelperApp.swift",
                "PipelineCoordinator.swift",
                "Monitor/HybridMonitor.swift",
                "Detector/TextAnalyzer.swift",
                "Detector/DebounceManager.swift",
                "Detector/Models.swift",
                "LLM/LLMService.swift",
                "LLM/SuggestionCache.swift",
                "Input/TextReplacer.swift",
                "UI/SuggestionPanelController.swift",
                "UI/SuggestionView.swift",
                "UI/SettingsView.swift",
                "Services/ConfigurationManager.swift",
                "Utilities/Constants.swift",
                "Utilities/Extensions.swift"
            ]
        )
    ]
)
