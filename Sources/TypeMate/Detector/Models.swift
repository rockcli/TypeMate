import Foundation

// MARK: - Data Models

struct SuggestionResponse: Sendable, Identifiable, Equatable {
    let id = UUID()
    let primarySuggestion: String
    let alternatives: [String]
    let mode: AnalysisMode
    let latency: TimeInterval
    let source: SuggestionSource
    let timestamp: Date

    enum SuggestionSource: String, Sendable {
        case cache
        case api
    }
}

struct AppSettings: Codable, Sendable, Equatable {
    var enableTranslation: Bool = true
    var enableImprovement: Bool = true
    var debounceMilliseconds: Int = 300
    var autoDismissDelay: TimeInterval = AppConstants.panelAutoDismissSeconds
    var apiTimeoutSeconds: TimeInterval = AppConstants.apiTimeout
    var fontSize: Double = 14
    var maxCacheSize: Int = AppConstants.cacheMaxEntries
    var cacheTTLSeconds: TimeInterval = AppConstants.cacheTTLSeconds
    var baseURL: String = AppConstants.deepSeekBaseURL
    var modelName: String = AppConstants.deepSeekModel

    static let `default` = AppSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enableTranslation = try c.decodeIfPresent(Bool.self, forKey: .enableTranslation) ?? true
        enableImprovement = try c.decodeIfPresent(Bool.self, forKey: .enableImprovement) ?? true
        debounceMilliseconds = try c.decodeIfPresent(Int.self, forKey: .debounceMilliseconds) ?? 300
        autoDismissDelay = try c.decodeIfPresent(TimeInterval.self, forKey: .autoDismissDelay) ?? AppConstants.panelAutoDismissSeconds
        apiTimeoutSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .apiTimeoutSeconds) ?? AppConstants.apiTimeout
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14
        maxCacheSize = try c.decodeIfPresent(Int.self, forKey: .maxCacheSize) ?? AppConstants.cacheMaxEntries
        cacheTTLSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .cacheTTLSeconds) ?? AppConstants.cacheTTLSeconds

        let decodedBaseURL = try c.decodeIfPresent(String.self, forKey: .baseURL)?.trimmingCharacters(in: .whitespacesAndNewlines)
        baseURL = (decodedBaseURL?.isEmpty == false) ? decodedBaseURL! : AppConstants.deepSeekBaseURL

        let decodedModel = try c.decodeIfPresent(String.self, forKey: .modelName)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let decodedModel, !decodedModel.isEmpty {
            modelName = decodedModel == "deepseek-v4-flash" ? AppConstants.deepSeekModel : decodedModel
        } else {
            modelName = AppConstants.deepSeekModel
        }
    }
}

// MARK: - Runtime State

@MainActor
final class AppState: ObservableObject {
    @Published var monitoringStatus: MonitoringStatus = .notMonitoring
    @Published var suggestionState: SuggestionState = .idle
    @Published var currentSuggestion: SuggestionResponse?
    @Published var isPanelVisible = false
    @Published var lastError: TypeMateError?
    @Published var inputBuffer: String = ""
    @Published var weChatIsFrontmost = false

    var settings: AppSettings = .default
    var dismissTimer: Task<Void, Never>?

    func resetPipeline() {
        suggestionState = .idle
        currentSuggestion = nil
        isPanelVisible = false
        dismissTimer?.cancel()
        dismissTimer = nil
    }
}

enum MonitoringStatus: String, Sendable {
    case notMonitoring
    case monitoring
    case unavailable   // WeChat not running
    case noPermission  // Input Monitoring not granted
}

enum SuggestionState: Sendable, Equatable {
    case idle
    case debouncing
    case analyzing
    case fetching
    case showing(SuggestionResponse)
    case error(TypeMateError)
}

// MARK: - Error Types

enum TypeMateError: LocalizedError, Sendable, Equatable {
    case noAPIKey
    case networkError(String)
    case decodingError
    case rateLimited
    case timeout
    case invalidResponse(String)
    case weChatNotRunning
    case noPermission
    case bufferTooShort

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "API key not configured. Set in Settings or export ANTHROPIC_API_KEY."
        case .networkError(let msg): return "Network error: \(msg)"
        case .decodingError: return "Failed to parse API response."
        case .rateLimited: return "Rate limited. Wait a moment."
        case .timeout: return "Request timed out."
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .weChatNotRunning: return "WeChat is not running."
        case .noPermission: return "Input Monitoring permission required."
        case .bufferTooShort: return "Not enough text to analyze."
        }
    }
}

// MARK: - WeChat State

struct WeChatState: Sendable {
    let pid: pid_t
    var isAccessible: Bool = false
    var isMonitoring: Bool = false
    var lastKnownText: String = ""
}
