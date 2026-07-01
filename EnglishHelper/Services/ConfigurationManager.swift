import Foundation
import Security

/// Configuration persistence: UserDefaults + Keychain
enum ConfigurationManager {
    // MARK: - Settings

    static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "appSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings.default
        }
        return settings
    }

    static func saveSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "appSettings")
    }

    // MARK: - API Key (Keychain)

    static func getAPIKey() -> String? {
        // 1. Check environment variable first (from zshrc)
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }

        // 2. Check Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.englishhelper",
            kSecAttrAccount as String: "deepseek-api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            // Check both possible env var names
            return ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"]
                ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        }

        return key
    }

    static func saveAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.englishhelper",
            kSecAttrAccount as String: "deepseek-api-key",
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.englishhelper",
            kSecAttrAccount as String: "deepseek-api-key",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status: status)
        }
    }
}

enum KeychainError: LocalizedError {
    case encodingFailed
    case storeFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode API key."
        case .storeFailed(let s): return "Keychain error: \(s)"
        }
    }
}
