import Foundation

public struct GroqRetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let retryableStatusCodes: Set<Int>

    public static let `default` = GroqRetryPolicy(
        maxRetries: 2,
        baseDelay: 1.0,
        maxDelay: 10.0,
        retryableStatusCodes: [429, 500, 502, 503, 504]
    )

    public static let aggressive = GroqRetryPolicy(
        maxRetries: 4,
        baseDelay: 0.5,
        maxDelay: 30.0,
        retryableStatusCodes: [429, 500, 502, 503, 504]
    )

    public static let none = GroqRetryPolicy(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        retryableStatusCodes: []
    )

    public init(
        maxRetries: Int = 2,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 10.0,
        retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }

    public func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0..<0.5)
        return min(exponential + jitter, maxDelay)
    }

    public func shouldRetry(error: GroqError, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        switch error {
        case .rateLimited, .serverError, .networkError, .requestTimedOut, .streamError:
            return true
        default:
            return false
        }
    }

    public func shouldRetry(statusCode: Int) -> Bool {
        retryableStatusCodes.contains(statusCode)
    }
}
