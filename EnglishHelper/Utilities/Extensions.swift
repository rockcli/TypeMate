import Foundation

// MARK: - String + Chinese Detection
extension String {
    /// Check if string contains Chinese characters (CJK Unified Ideographs + Extension A)
    var containsChineseCharacters: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||   // CJK Unified Ideographs
            (0x3400...0x4DBF).contains(scalar.value) ||   // CJK Extension A
            (0xF900...0xFAFF).contains(scalar.value)       // CJK Compatibility Ideographs
        }
    }

    /// Normalize text for cache key generation
    var normalizedForCache: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
    }

    /// Count English words (space-separated, excluding Chinese characters)
    var englishWordCount: Int {
        components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && !$0.containsChineseCharacters }
            .count
    }
}

// MARK: - Process
extension ProcessInfo {
    static var isDebugMode: Bool {
        ProcessInfo.processInfo.environment["ENGLISHHELPER_DEBUG"] == "1"
    }
}
