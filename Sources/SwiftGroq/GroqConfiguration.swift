import Foundation
import Security

public struct GroqConfiguration: Sendable {
    public static let defaultBaseURL = "https://api.groq.com/openai/v1/chat/completions"

    public let apiKey: String
    public let baseURL: String
    public let defaultModel: String
    public let defaultTemperature: Double
    public let defaultMaxTokens: Int
    public let timeoutInterval: TimeInterval

    public init(
        apiKey: String,
        baseURL: String = GroqConfiguration.defaultBaseURL,
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

public enum GroqAPIKeySource {
    case key(String)
    case environment(variable: String = "GROQ_API_KEY")
    case infoPlist(key: String = "GROQ_API_KEY")
    case keychain(account: String = "com.umituz.swiftgroq")
    /// Try each source in order, returning the first non-empty value.
    ///
    /// Use this to make configuration robust across environments. For example,
    /// `.any([.infoPlist(), .environment()])` resolves the key from the app bundle
    /// (baked into the binary at build time, so it works in TestFlight / App Review
    /// builds) while still falling back to the process environment during local
    /// development. Relying on a single source such as `.environment` alone is a
    /// common pitfall: `ProcessInfo.processInfo.environment` is only populated when
    /// the app is launched from a shell that exports the variable, so it is empty in
    /// release/device builds and leaves the client unconfigured.
    case any([GroqAPIKeySource])

    public func resolve() -> String? {
        switch self {
        case .key(let value):
            return value.isEmpty ? nil : value

        case .environment(let variable):
            let value = ProcessInfo.processInfo.environment[variable]
            return (value?.isEmpty ?? true) ? nil : value

        case .infoPlist(let key):
            let value = Bundle.main.infoDictionary?[key] as? String
            return (value?.isEmpty ?? true) ? nil : value

        case .keychain(let account):
            return KeychainHelper.load(key: account)

        case .any(let sources):
            for source in sources {
                if let resolved = source.resolve(), !resolved.isEmpty {
                    return resolved
                }
            }
            return nil
        }
    }
}

public enum KeychainHelper {
    private static let serviceIdentifier = "com.umituz.swiftgroq"

    @discardableResult
    public static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    public static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
