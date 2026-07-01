import Foundation

/// DeepSeek API client using Anthropic-compatible Messages endpoint
/// Fixes Codex C-4 (URL path) and adds retry with exponential backoff
final class LLMService: @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String
    private let apiKey: String
    private let model: String
    private var consecutiveErrors = 0

    init(apiKey: String, baseURL: String = AppConstants.deepSeekBaseURL, model: String = AppConstants.deepSeekModel) {
        self.apiKey = apiKey
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.model = model

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = AppConstants.apiTimeout
        config.timeoutIntervalForResource = AppConstants.apiTimeout
        config.waitsForConnectivity = true  // Fixes Codex V2-M3-adjacent: handles network flakiness
        self.session = URLSession(configuration: config)
    }

    /// Get translation or improvement suggestion
    func suggest(for text: String, mode: AnalysisMode) async throws -> SuggestionResponse {
        let startTime = Date()

        let systemPrompt: String
        let userMessage: String

        switch mode {
        case .chineseToEnglish:
            systemPrompt = PromptTemplates.translationSystem
            userMessage = text
        case .englishToChinese:
            systemPrompt = PromptTemplates.englishToChineseSystem
            userMessage = text
        case .englishImprovement:
            systemPrompt = PromptTemplates.improvementSystem
            userMessage = text
        case .skip:
            throw EnglishHelperError.bufferTooShort
        }

        // Fixes Codex C-4: Correct URL construction
        // baseURL is https://api.deepseek.com/anthropic
        // Messages API path is /v1/messages
        let urlString = "\(baseURL)/v1/messages"
        guard let url = URL(string: urlString) else {
            throw EnglishHelperError.invalidResponse("Invalid URL: \(urlString)")
        }

        // Build Anthropic Messages API request
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ],
            "thinking": ["type": "disabled"]  // Disable reasoning for faster translation
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Retry with exponential backoff
        let maxRetries = 3
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EnglishHelperError.networkError("Invalid response type")
                }

                switch httpResponse.statusCode {
                case 200:
                    let result = try parseResponse(data, mode: mode, startTime: startTime)
                    consecutiveErrors = 0
                    return result
                case 429:
                    consecutiveErrors += 1
                    throw EnglishHelperError.rateLimited
                case 401, 403:
                    throw EnglishHelperError.noAPIKey
                case 500...599:
                    consecutiveErrors += 1
                    throw EnglishHelperError.networkError("Server error \(httpResponse.statusCode)")
                default:
                    let body = String(data: data, encoding: .utf8) ?? ""
                    throw EnglishHelperError.invalidResponse("HTTP \(httpResponse.statusCode): \(body.prefix(200))")
                }
            } catch let error as EnglishHelperError {
                lastError = error
            } catch {
                lastError = EnglishHelperError.networkError(error.localizedDescription)
            }

            // Exponential backoff: 1s, 2s, 4s
            if attempt < maxRetries - 1 {
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
            }
        }

        throw lastError ?? EnglishHelperError.timeout
    }

    private func parseResponse(_ data: Data, mode: AnalysisMode, startTime: Date) throws -> SuggestionResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            // Try Anthropic format: content array with text blocks
            throw EnglishHelperError.decodingError
        }

        var fullText = ""
        for block in content {
            if let type = block["type"] as? String, type == "text",
               let text = block["text"] as? String {
                fullText += text
            }
        }

        guard !fullText.isEmpty else {
            throw EnglishHelperError.invalidResponse("Empty response content")
        }

        // Parse suggestions from response
        // Format expected: each suggestion on a new line, or numbered
        let lines = fullText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }

        let primary = lines.first ?? fullText
        let alternatives = Array(lines.dropFirst().prefix(2))

        return SuggestionResponse(
            primarySuggestion: primary,
            alternatives: alternatives,
            mode: mode,
            latency: Date().timeIntervalSince(startTime),
            source: .api,
            timestamp: Date()
        )
    }
}

// MARK: - Prompt Templates
enum PromptTemplates {
    static let translationSystem = """
    You are a Chinese-to-English translation assistant for WeChat messages.
    Translate the user's Chinese text (which may contain some English words) into natural, conversational English.
    Keep any existing English words unchanged.
    Return ONLY the translation — no explanations, no notes.
    The tone should be casual and friendly, appropriate for chatting with friends.
    """

    static let improvementSystem = """
    You are an English writing assistant for WeChat messages.
    Suggest 1-3 more natural, native-sounding alternatives to the given English text.
    Keep the original tone and meaning.
    Return each suggestion on a separate line.
    Do NOT include explanations or commentary — just the improved versions.
    """

    static let englishToChineseSystem = """
    You are an English-to-Chinese translation assistant for WeChat messages.
    Translate the user's English text into natural, conversational Chinese.
    Return ONLY the Chinese translation — no explanations, no notes.
    Keep the tone casual and friendly, appropriate for chatting with friends.
    """

}
