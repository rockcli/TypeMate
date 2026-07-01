import Foundation

enum AppConstants {
    static let weChatBundleID = "com.tencent.xinWeChat"
    static let appName = "TypeMate"

    // DeepSeek API (Anthropic-compatible endpoint)
    // Base URL already includes /anthropic — append /v1/messages for the Messages API
    static let deepSeekBaseURL = "https://api.deepseek.com/anthropic"
    static let deepSeekMessagesPath = "/v1/messages"
    static let deepSeekModel = "deepseek-v4-flash"
    static let apiTimeout: TimeInterval = 10.0

    // Debounce
    static let debounceMilliseconds: UInt64 = 300_000_000  // 300ms in ns

    // Polling (hybrid approach)
    static let axPollInterval: TimeInterval = 0.2  // 200ms

    // Input
    static let maxBufferSize = 500
    static let minEnglishWordsForImprovement = 3
    static let minTextLength = 2

    // Panel
    static let panelAutoDismissSeconds: TimeInterval = 5.0
    static let panelDefaultWidth: CGFloat = 360
    static let panelDefaultHeight: CGFloat = 180

    // Clipboard restore delay
    static let clipboardRestoreDelay: TimeInterval = 0.5

    // Cache
    static let cacheMaxEntries = 100
    static let cacheTTLSeconds: TimeInterval = 3600  // 1 hour

    // Notification names
    static let monitoringStatusChanged = Notification.Name("com.englishhelper.monitoringStatusChanged")
    static let suggestionReady = Notification.Name("com.englishhelper.suggestionReady")
}
