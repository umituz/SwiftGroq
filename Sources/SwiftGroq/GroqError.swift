import Foundation

public enum GroqError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidURL
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case insufficientQuota
    case serverError(statusCode: Int)
    case networkError(Error)
    case invalidResponse
    case emptyResponse
    case decodingFailed(Error)
    case requestTimedOut

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Groq API key is not configured."
        case .invalidURL:
            return "Invalid API URL."
        case .unauthorized:
            return "Invalid API key."
        case .rateLimited:
            return "Rate limit reached. Please try again later."
        case .insufficientQuota:
            return "API quota exceeded."
        case .serverError(let code):
            return "Server error (HTTP \(code))."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .emptyResponse:
            return "Empty response from AI."
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .requestTimedOut:
            return "Request timed out."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .networkError, .requestTimedOut:
            return true
        default:
            return false
        }
    }
}
