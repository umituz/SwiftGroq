import Foundation

public actor GroqRateLimiter {
    public static let shared = GroqRateLimiter()

    private struct ModelUsage {
        let model: String
        let tokens: Int
        let timestamp: Date
    }

    private var tokenTimestamps: [ModelUsage] = []
    private var dailyRequestCounts: [String: Int] = [:]
    private var lastResetDate: String = ""

    private let maxRequestsPerMinute: Int
    private let maxTokensPerMinute: Int

    private static let dateFactory: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    public init(
        maxRequestsPerMinute: Int = 30,
        maxTokensPerMinute: Int = 12000
    ) {
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.maxTokensPerMinute = maxTokensPerMinute
        self.lastResetDate = Self.dateFactory.string(from: Date())
    }

    public func canMakeRequest(model: String = "", estimatedTokens: Int = 0) -> Bool {
        resetDailyIfNeeded()
        pruneOldTimestamps()

        if !model.isEmpty {
            let modelLimit = ModelRateLimits.limit(for: model)
            let dailyCount = dailyRequestCounts[model] ?? 0
            if dailyCount >= modelLimit.dailyRequests { return false }

            let oneMinuteAgo = Date().addingTimeInterval(-60)
            let tokensLastMinute = tokenTimestamps
                .filter { $0.model == model && $0.timestamp > oneMinuteAgo }
                .reduce(0) { $0 + $1.tokens }
            if tokensLastMinute + estimatedTokens > modelLimit.tpm { return false }
        }

        let totalRecent = tokenTimestamps.filter { $0.timestamp > Date().addingTimeInterval(-60) }.count
        guard totalRecent < maxRequestsPerMinute else { return false }

        return true
    }

    public func recordRequest(model: String = "", tokenCount: Int = 0) {
        resetDailyIfNeeded()

        tokenTimestamps.append(ModelUsage(model: model, tokens: tokenCount, timestamp: Date()))
        if !model.isEmpty {
            dailyRequestCounts[model, default: 0] += 1
        }

        pruneOldTimestamps()
    }

    public var remainingRequests: Int {
        pruneOldTimestamps()
        let recent = tokenTimestamps.filter { $0.timestamp > Date().addingTimeInterval(-60) }.count
        return max(0, maxRequestsPerMinute - recent)
    }

    public var remainingTokens: Int {
        pruneOldTimestamps()
        let used = tokenTimestamps
            .filter { $0.timestamp > Date().addingTimeInterval(-60) }
            .reduce(0) { $0 + $1.tokens }
        return max(0, maxTokensPerMinute - used)
    }

    public func waitForAvailability(model: String = "", estimatedTokens: Int = 0) async throws {
        let maxWait: TimeInterval = 60
        let checkInterval: UInt64 = 500_000_000
        let start = Date()

        while Date().timeIntervalSince(start) < maxWait {
            if canMakeRequest(model: model, estimatedTokens: estimatedTokens) {
                return
            }
            try await Task.sleep(nanoseconds: checkInterval)
        }

        throw GroqError.rateLimited(retryAfter: nil)
    }

    private func pruneOldTimestamps() {
        let cutoff = Date().addingTimeInterval(-120)
        tokenTimestamps = tokenTimestamps.filter { $0.timestamp > cutoff }
    }

    private func resetDailyIfNeeded() {
        let today = Self.dateFactory.string(from: Date())
        if today != lastResetDate {
            dailyRequestCounts.removeAll()
            lastResetDate = today
        }
    }
}

public struct ModelRateLimits: Sendable {
    public let tpm: Int
    public let dailyRequests: Int

    public static func limit(for model: String) -> ModelRateLimits {
        switch model {
        case GroqModel.llama33_70b.rawValue:
            return ModelRateLimits(tpm: 12000, dailyRequests: 6000)
        case GroqModel.llama31_8b.rawValue:
            return ModelRateLimits(tpm: 6000, dailyRequests: 6000)
        case GroqModel.llama32_1b.rawValue:
            return ModelRateLimits(tpm: 6000, dailyRequests: 6000)
        case GroqModel.llama32_3b.rawValue:
            return ModelRateLimits(tpm: 6000, dailyRequests: 6000)
        case GroqModel.llama32_11b_vision.rawValue:
            return ModelRateLimits(tpm: 12000, dailyRequests: 6000)
        case GroqModel.llama32_90b_vision.rawValue:
            return ModelRateLimits(tpm: 12000, dailyRequests: 6000)
        case GroqModel.mixtral8x7b.rawValue:
            return ModelRateLimits(tpm: 6000, dailyRequests: 6000)
        case GroqModel.gemma2_9b.rawValue:
            return ModelRateLimits(tpm: 6000, dailyRequests: 6000)
        case GroqModel.deepseekR1_70b.rawValue:
            return ModelRateLimits(tpm: 12000, dailyRequests: 6000)
        default:
            return ModelRateLimits(tpm: 12000, dailyRequests: 6000)
        }
    }
}
