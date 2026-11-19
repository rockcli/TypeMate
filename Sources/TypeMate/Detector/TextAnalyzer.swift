import Foundation

/// Analysis mode determined by text content
enum AnalysisMode: String, Sendable, CaseIterable {
    case chineseToEnglish
    case englishToChinese
    case englishImprovement
    case skip
}

enum AnalysisEngine: Sendable {
    /// Auto-detect mode: Chinese → English, English → improve
    static func analyze(_ text: String) -> AnalysisMode {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AppConstants.minTextLength else { return .skip }
        if trimmed.containsChineseCharacters { return .chineseToEnglish }
        if trimmed.englishWordCount >= AppConstants.minEnglishWordsForImprovement { return .englishImprovement }
        return .skip
    }

    /// Bidirectional translate: Chinese → English, English → Chinese
    static func analyzeForTranslate(_ text: String) -> AnalysisMode {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AppConstants.minTextLength else { return .skip }
        if trimmed.containsChineseCharacters { return .chineseToEnglish }
        return .englishToChinese
    }
}
