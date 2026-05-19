import Foundation

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

public enum GroqRole: String, Codable, Sendable, CaseIterable {
    case system
    case user
    case assistant
}

public enum GroqFinishReason: String, Codable, Sendable {
    case stop
    case length
    case contentFilter = "content_filter"
    case toolCalls = "tool_calls"
}

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

public enum GroqResponseFormatType: String, Codable, Sendable, CaseIterable {
    case json = "json_object"
    case text = "text"
}

public struct GroqResponseFormat: Codable, Equatable, Sendable {
    public let type: GroqResponseFormatType

    public static let json = GroqResponseFormat(type: .json)
    public static let text = GroqResponseFormat(type: .text)

    public init(type: GroqResponseFormatType) {
        self.type = type
    }
}

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

public struct GroqChoice: Codable, Sendable {
    public let index: Int
    public let message: GroqMessage
    public let finishReason: GroqFinishReason?

    private enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

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

public enum GroqModel: String, Sendable, CaseIterable {
    case llama33_70b = "llama-3.3-70b-versatile"
    case llama31_8b = "llama-3.1-8b-instant"
    case llama32_1b = "llama-3.2-1b-preview"
    case llama32_3b = "llama-3.2-3b-preview"
    case llama32_11b_vision = "llama-3.2-11b-vision-preview"
    case llama32_90b_vision = "llama-3.2-90b-vision-preview"
    case mixtral8x7b = "mixtral-8x7b-32768"
    case gemma2_9b = "gemma2-9b-it"
    case deepseekR1_70b = "deepseek-r1-distill-llama-70b"
}

public struct GroqStreamChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [GroqChunkChoice]
}

public struct GroqChunkChoice: Codable, Sendable {
    public let index: Int
    public let delta: GroqDelta
    public let finishReason: GroqFinishReason?

    private enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

public struct GroqDelta: Codable, Sendable {
    public let role: GroqRole?
    public let content: String?
}
