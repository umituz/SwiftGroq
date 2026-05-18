import Foundation

public actor GroqRateLimiter {
    public static let shared = GroqRateLimiter()

    private var requestTimestamps: [Date] = []
    private var tokenUsagePerMinute: Int = 0
    private var currentWindowStart: Date = Date()

    private let maxRequestsPerMinute: Int
    private let maxTokensPerMinute: Int
    private let minRequestInterval: TimeInterval

    public init(
        maxRequestsPerMinute: Int = 30,
        maxTokensPerMinute: Int = 12000,
        minRequestInterval: TimeInterval = 0.5
    ) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.maxTokensPerMinute = maxTokensPerMinute
        self.minRequestInterval = minRequestInterval
    }

    public func canMakeRequest(estimatedTokens: Int = 0) -> Bool {
        pruneOldTimestamps()

        let requestCount = requestTimestamps.count
        guard requestCount < maxRequestsPerMinute else { return false }

        if estimatedTokens > 0 {
            let totalTokens = tokenUsagePerMinute + estimatedTokens
            guard totalTokens < maxTokensPerMinute else { return false }
        }

        return true
    }

    public func recordRequest(tokenCount: Int = 0) {
        pruneOldTimestamps()
        requestTimestamps.append(Date())
        tokenUsagePerMinute += tokenCount
    }

    public var remainingRequests: Int {
        pruneOldTimestamps()
        return max(0, maxRequestsPerMinute - requestTimestamps.count)
    }

    public var remainingTokens: Int {
        pruneOldTimestamps()
        return max(0, maxTokensPerMinute - tokenUsagePerMinute)
    }

    public func waitForAvailability(estimatedTokens: Int = 0) async throws {
        let maxWait: TimeInterval = 60
        let checkInterval: UInt64 = 500_000_000
        let start = Date()

        while Date().timeIntervalSince(start) < maxWait {
            if canMakeRequest(estimatedTokens: estimatedTokens) {
                return
            }
            try await Task.sleep(nanoseconds: checkInterval)
        }

        throw GroqError.rateLimited(retryAfter: nil)
    }

    private func pruneOldTimestamps() {
        let cutoff = Date().addingTimeInterval(-60)
        requestTimestamps = requestTimestamps.filter { $0 > cutoff }

        if currentWindowStart < cutoff {
            tokenUsagePerMinute = 0
            currentWindowStart = Date()
        }
    }
}
