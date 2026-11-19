import Foundation

/// Thread-safe suggestion cache using an actor-wrapped NSCache
actor SuggestionCache {
    private let cache = NSCache<NSString, CacheEntry>()
    private var ttl: TimeInterval

    init(maxCount: Int = AppConstants.cacheMaxEntries, ttl: TimeInterval = AppConstants.cacheTTLSeconds) {
        cache.countLimit = maxCount
        cache.totalCostLimit = 5_000_000  // ~5MB
        self.ttl = ttl
    }

    func get(text: String, mode: AnalysisMode) -> SuggestionResponse? {
        let key = cacheKey(text: text, mode: mode)
        guard let entry = cache.object(forKey: key as NSString) else { return nil }

        if entry.isExpired {
            cache.removeObject(forKey: key as NSString)
            return nil
        }

        return entry.response
    }

    func set(text: String, mode: AnalysisMode, response: SuggestionResponse) {
        let key = cacheKey(text: text, mode: mode)
        let entry = CacheEntry(response: response, ttl: ttl)
        cache.setObject(entry, forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }

    func updateTTL(_ newTTL: TimeInterval) {
        ttl = newTTL
    }

    private func cacheKey(text: String, mode: AnalysisMode) -> String {
        "\(text.normalizedForCache)|\(mode.rawValue)"
    }
}

/// Wrapper for NSCache (non-Sendable) to satisfy Swift 6 concurrency
final class CacheEntry: @unchecked Sendable {
    let response: SuggestionResponse
    let createdAt: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) >= ttl
    }

    init(response: SuggestionResponse, ttl: TimeInterval) {
        self.response = response
        self.createdAt = Date()
        self.ttl = ttl
    }
}
