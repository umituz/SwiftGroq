import Foundation

public enum GroqError: LocalizedError, Sendable {
    case notConfigured
    case missingAPIKey
    case invalidURL
    case invalidRequest(String)
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case insufficientQuota
    case serverError(statusCode: Int, message: String?)
    case networkError(String)
    case invalidResponse
    case emptyResponse
    case decodingFailed(Error)
    case requestTimedOut
    case streamError(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "GroqClient has not been configured."
        case .missingAPIKey:
            return "Groq API key is not configured."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .unauthorized:
            return "Invalid API key. Check your Groq API key in console.groq.com."
        case .rateLimited:
            return "Rate limit reached. Please try again in a moment."
        case .insufficientQuota:
            return "API quota exceeded. Check your plan at console.groq.com."
        case .serverError(let code, let message):
            if let message {
                return "Server error (HTTP \(code)): \(message)"
            }
            return "Server error (HTTP \(code)). The service may be temporarily unavailable."
        case .networkError(let description):
            return "Network error: \(description)"
        case .invalidResponse:
            return "Invalid response from server."
        case .emptyResponse:
            return "Empty response from AI."
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .requestTimedOut:
            return "Request timed out. Check your internet connection and try again."
        case .streamError(let description):
            return "Streaming error: \(description)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Call GroqClient.configure() before making requests."
        case .missingAPIKey:
            return "Configure the API key using GroqClient.configure(apiKeySource:) before making requests."
        case .invalidRequest:
            return "Check your request parameters and try again."
        case .unauthorized:
            return "Verify your API key is correct at console.groq.com/keys."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Wait \(seconds) seconds before retrying."
            }
            return "Wait a moment before retrying."
        case .insufficientQuota:
            return "Upgrade your plan or wait for quota renewal at console.groq.com."
        case .serverError:
            return "This is a server-side issue. Try again later."
        case .networkError:
            return "Check your internet connection and try again."
        case .requestTimedOut:
            return "Check your internet connection or try with a shorter prompt."
        case .invalidResponse, .emptyResponse:
            return "Try rephrasing your prompt or try again."
        case .decodingFailed:
            return "The AI response format was unexpected. Try again or adjust your prompt."
        case .streamError:
            return "The streaming connection was interrupted. Try again."
        case .invalidURL:
            return nil
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .networkError, .requestTimedOut, .streamError:
            return true
        case .invalidRequest, .notConfigured, .missingAPIKey, .invalidURL, .unauthorized,
             .insufficientQuota, .invalidResponse, .emptyResponse, .decodingFailed:
            return false
        }
    }

    public var isConfigurationError: Bool {
        switch self {
        case .notConfigured, .missingAPIKey, .unauthorized:
            return true
        case .invalidURL, .invalidRequest, .rateLimited, .insufficientQuota,
             .serverError, .networkError, .invalidResponse, .emptyResponse,
             .decodingFailed, .requestTimedOut, .streamError:
            return false
        }
    }
}
