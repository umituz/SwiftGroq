import Foundation

// MARK: - Chat Message

public struct GroqMessage: Codable, Equatable, Sendable {
    public let role: GroqRole
    public let content: String

    public init(role: GroqRole, content: String) {
        self.role = role
        self.content = content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawRole = try container.decode(String.self, forKey: .role)
        self.role = GroqRole(rawValue: rawRole) ?? .user
        self.content = try container.decode(String.self, forKey: .content)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role.rawValue, forKey: .role)
        try container.encode(content, forKey: .content)
    }

    private enum CodingKeys: String, CodingKey {
        case role, content
    }
}

// MARK: - Message Role

public enum GroqRole: String, Codable, Sendable, CaseIterable {
    case system
    case user
    case assistant
}

// MARK: - Chat Request

public struct GroqChatRequest: Codable, Sendable {
    public let model: String
    public let messages: [GroqMessage]
    public let temperature: Double
    public let maxTokens: Int
    public let topP: Double
    public let stream: Bool
    public let responseFormat: GroqResponseFormat?

    public init(
        model: String = GroqModel.llama33_70b.rawValue,
        messages: [GroqMessage],
        temperature: Double = 0.7,
        maxTokens: Int = 1024,
        topP: Double = 1.0,
        stream: Bool = false,
        responseFormat: GroqResponseFormat? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.stream = stream
        self.responseFormat = responseFormat
    }

    private enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case responseFormat = "response_format"
    }
}

// MARK: - Response Format

public struct GroqResponseFormat: Codable, Equatable, Sendable {
    public let type: String

    public static let json = GroqResponseFormat(type: "json_object")
    public static let text = GroqResponseFormat(type: "text")

    public init(type: String) {
        self.type = type
    }
}

// MARK: - Chat Response

public struct GroqChatResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [GroqChoice]
    public let usage: GroqUsage?

    public var text: String? {
        choices.first?.message.content
    }
}

// MARK: - Choice

public struct GroqChoice: Codable, Sendable {
    public let index: Int
    public let message: GroqMessage
    public let finishReason: String?

    private enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

// MARK: - Token Usage

public struct GroqUsage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int
    public let totalTokens: Int
    public let promptTime: Double?
    public let completionTime: Double?

    private enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case promptTime = "prompt_time"
        case completionTime = "completion_time"
    }
}

// MARK: - Model Identifier

public enum GroqModel: String, Sendable, CaseIterable {
    case llama33_70b = "llama-3.3-70b-versatile"
    case llama31_8b = "llama-3.1-8b-instant"
    case llama31_70b = "llama-3.1-70b-versatile"
    case mixtral8x7b = "mixtral-8x7b-32768"
    case gemma2_9b = "gemma2-9b-it"
}
