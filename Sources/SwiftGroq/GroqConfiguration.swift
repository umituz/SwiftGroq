import Foundation

// MARK: - Configuration

public struct GroqConfiguration: Sendable {
    public let apiKey: String
    public let baseURL: String
    public let defaultModel: String
    public let defaultTemperature: Double
    public let defaultMaxTokens: Int
    public let timeoutInterval: TimeInterval

    public init(
        apiKey: String,
        baseURL: String = "https://api.groq.com/openai/v1/chat/completions",
        defaultModel: String = GroqModel.llama33_70b.rawValue,
        defaultTemperature: Double = 0.7,
        defaultMaxTokens: Int = 1024,
        timeoutInterval: TimeInterval = 30.0
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.defaultTemperature = defaultTemperature
        self.defaultMaxTokens = defaultMaxTokens
        self.timeoutInterval = timeoutInterval
    }
}

// MARK: - API Key Sources

public enum GroqAPIKeySource {
    case key(String)
    case environment(variable: String = "GROQ_API_KEY")
    case infoPlist(key: String = "GROQ_API_KEY")
    case keychain(account: String = "com.umituz.swiftgroq")
    case xcconfig(key: String = "GROQ_API_KEY")

    public func resolve() -> String? {
        switch self {
        case .key(let value):
            return value.isEmpty ? nil : value

        case .environment(let variable):
            return ProcessInfo.processInfo.environment[variable]

        case .infoPlist(let key):
            return Bundle.main.infoDictionary?[key] as? String

        case .keychain(let account):
            return KeychainHelper.load(key: account)

        case .xcconfig(let key):
            return Bundle.main.infoDictionary?[key] as? String
        }
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
