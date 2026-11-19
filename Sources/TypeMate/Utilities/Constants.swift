import Foundation

enum AppConstants {
    static let weChatBundleID = "com.tencent.xinWeChat"
    static let appName = "TypeMate"

    // DeepSeek API (Anthropic-compatible Messages endpoint)
    static let deepSeekBaseURL = "https://api.deepseek.com/anthropic"
    static let deepSeekMessagesPath = "/v1/messages"
    static let deepSeekModel = "deepseek-flash"
    static let deepSeekModels = ["deepseek-flash", "deepseek-v4-pro"]
    static let apiTimeout: TimeInterval = 10.0

    // Debounce
    static let debounceMilliseconds: UInt64 = 300_000_000  // 300ms in ns

    // Input
    static let maxBufferSize = 500
    static let minEnglishWordsForImprovement = 3
    static let minTextLength = 2

    // Panel
    static let panelAutoDismissSeconds: TimeInterval = 10.0
    static let panelDefaultWidth: CGFloat = 360
    static let panelDefaultHeight: CGFloat = 180

    // Clipboard restore delay
    static let clipboardRestoreDelay: TimeInterval = 0.5

    // Cache
    static let cacheMaxEntries = 100
    static let cacheTTLSeconds: TimeInterval = 3600  // 1 hour

    // Notification names
    static let monitoringStatusChanged = Notification.Name("com.typemate.monitoringStatusChanged")
    static let suggestionReady = Notification.Name("com.typemate.suggestionReady")
}
