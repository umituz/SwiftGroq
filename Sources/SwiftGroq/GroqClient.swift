import Foundation

// MARK: - Token Usage

public struct GroqTokenUsage: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int

    public var totalTokens: Int { inputTokens + outputTokens }

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - Token Estimator

public enum GroqTokenEstimator {
    public static func estimate(text: String) -> Int {
        max(1, text.count / 4)
    }

    public static func estimateRequest(
        systemPrompt: String,
        history: [GroqMessage],
        userMessage: String
    ) -> GroqTokenUsage {
        let input = estimate(text: systemPrompt)
            + history.reduce(0) { $0 + estimate(text: $1.content) }
            + estimate(text: userMessage)
        return GroqTokenUsage(inputTokens: input, outputTokens: 0)
    }

    public static func estimateFullUsage(
        systemPrompt: String,
        history: [GroqMessage],
        userMessage: String,
        response: String
    ) -> GroqTokenUsage {
        let request = estimateRequest(
            systemPrompt: systemPrompt,
            history: history,
            userMessage: userMessage
        )
        return GroqTokenUsage(
            inputTokens: request.inputTokens,
            outputTokens: estimate(text: response)
        )
    }
}

// MARK: - Groq Client

public final class GroqClient: Sendable {
    public static let shared = GroqClient()

    private let configuration: GroqConfiguration
    private let rateLimiter: GroqRateLimiter
    private let retryPolicy: GroqRetryPolicy
    private let session: URLSession

    private init(
        configuration: GroqConfiguration,
        rateLimiter: GroqRateLimiter = .shared,
        retryPolicy: GroqRetryPolicy = .default,
        certificatePinning: Bool = false
    ) {
        self.configuration = configuration
        self.rateLimiter = rateLimiter
        self.retryPolicy = retryPolicy

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeoutInterval
        config.waitsForConnectivity = true

        if certificatePinning {
            self.session = URLSession(
                configuration: config,
                delegate: GroqCertificatePinner.shared,
                delegateQueue: nil
            )
        } else {
            self.session = URLSession(configuration: config)
        }
    }

    private convenience init() {
        self.init(
            configuration: GroqConfiguration(apiKey: ""),
            rateLimiter: .shared,
            retryPolicy: .default,
            certificatePinning: false
        )
    }

    // MARK: - Factory

    private static var _configuredInstance: GroqClient?

    public static var isConfigured: Bool {
        guard let instance = _configuredInstance else { return false }
        return !instance.configuration.apiKey.isEmpty
    }

    public static func configure(
        _ configuration: GroqConfiguration,
        rateLimiter: GroqRateLimiter = .shared,
        retryPolicy: GroqRetryPolicy = .default,
        certificatePinning: Bool = false
    ) {
        _configuredInstance = GroqClient(
            configuration: configuration,
            rateLimiter: rateLimiter,
            retryPolicy: retryPolicy,
            certificatePinning: certificatePinning
        )
    }

    public static func configure(
        apiKeySource: GroqAPIKeySource,
        model: GroqModel = .llama33_70b,
        temperature: Double = 0.7,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 30.0,
        certificatePinning: Bool = false
    ) throws {
        guard let apiKey = apiKeySource.resolve(), !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }
        let config = GroqConfiguration(
            apiKey: apiKey,
            defaultModel: model.rawValue,
            defaultTemperature: temperature,
            defaultMaxTokens: maxTokens,
            timeoutInterval: timeout
        )
        configure(config, certificatePinning: certificatePinning)
    }

    public static var configured: GroqClient {
        if let instance = _configuredInstance {
            return instance
        }
        return shared
    }

    // MARK: - Chat Completion

    public func chat(
        messages: [GroqMessage],
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: GroqResponseFormat? = nil,
        sanitizeInput: Bool = true
    ) async throws -> String {
        guard !configuration.apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }

        let processedMessages = sanitizeInput
            ? messages.map { GroqMessage(role: $0.role, content: GroqPromptSanitizer.sanitize($0.content)) }
            : messages

        let resolvedModel = model ?? configuration.defaultModel

        let request = GroqChatRequest(
            model: resolvedModel,
            messages: processedMessages,
            temperature: temperature ?? configuration.defaultTemperature,
            maxTokens: maxTokens ?? configuration.defaultMaxTokens,
            responseFormat: responseFormat
        )

        let response: GroqChatResponse = try await executeWithRetry(request, model: resolvedModel)
        guard let text = response.text, !text.isEmpty else {
            throw GroqError.emptyResponse
        }
        return GroqResponseFormatter.cleanResponse(text)
    }

    // MARK: - Typed Decode

    public func decode<T: Decodable>(
        _ type: T.Type,
        messages: [GroqMessage],
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        sanitizeInput: Bool = true
    ) async throws -> T {
        let rawText = try await chat(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: .json,
            sanitizeInput: sanitizeInput
        )

        let jsonText = GroqResponseFormatter.extractJSON(from: rawText) ?? rawText

        guard let data = jsonText.data(using: .utf8) else {
            throw GroqError.decodingFailed(DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Failed to convert response to data")
            ))
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GroqError.decodingFailed(error)
        }
    }

    // MARK: - Convenience Methods

    public func systemChat(
        systemPrompt: String,
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        try await chat(
            messages: [
                GroqMessage(role: .system, content: systemPrompt),
                GroqMessage(role: .user, content: userMessage)
            ],
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    public func chatWithHistory(
        systemPrompt: String,
        history: [GroqMessage],
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        var messages: [GroqMessage] = [GroqMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: history)
        messages.append(GroqMessage(role: .user, content: userMessage))

        return try await chat(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }

    public func rawChat(
        messages: [GroqMessage],
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: GroqResponseFormat? = nil,
        sanitizeInput: Bool = true
    ) async throws -> GroqChatResponse {
        guard !configuration.apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }

        let processedMessages = sanitizeInput
            ? messages.map { GroqMessage(role: $0.role, content: GroqPromptSanitizer.sanitize($0.content)) }
            : messages

        let resolvedModel = model ?? configuration.defaultModel

        let request = GroqChatRequest(
            model: resolvedModel,
            messages: processedMessages,
            temperature: temperature ?? configuration.defaultTemperature,
            maxTokens: maxTokens ?? configuration.defaultMaxTokens,
            responseFormat: responseFormat
        )

        return try await executeWithRetry(request, model: resolvedModel)
    }

    // MARK: - Execute with Retry

    private func executeWithRetry(_ request: GroqChatRequest, model: String) async throws -> GroqChatResponse {
        var lastError: GroqError?

        for attempt in 0...retryPolicy.maxRetries {
            do {
                let tokenEstimate = estimateTokens(for: request.messages)
                try await rateLimiter.waitForAvailability(model: model, estimatedTokens: tokenEstimate)
                let response = try await performRequest(request)
                await rateLimiter.recordRequest(
                    model: model,
                    tokenCount: response.usage?.totalTokens ?? tokenEstimate
                )
                return response
            } catch let error as GroqError {
                lastError = error
                if retryPolicy.shouldRetry(error: error, attempt: attempt) {
                    let delay: TimeInterval
                    if case .rateLimited(let retryAfter) = error, let after = retryAfter {
                        delay = TimeInterval(after)
                    } else {
                        delay = retryPolicy.delay(for: attempt)
                    }
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            }
        }

        throw lastError ?? GroqError.invalidResponse
    }

    // MARK: - HTTP Request

    private func performRequest(_ request: GroqChatRequest) async throws -> GroqChatResponse {
        guard let url = URL(string: configuration.baseURL) else {
            throw GroqError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = configuration.timeoutInterval

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw GroqError.invalidResponse
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw GroqError.requestTimedOut
            }
            throw GroqError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw GroqError.unauthorized
        case 402:
            throw GroqError.insufficientQuota
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw GroqError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw GroqError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw GroqError.serverError(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(GroqChatResponse.self, from: data)
        } catch {
            throw GroqError.decodingFailed(error)
        }
    }

    // MARK: - Token Estimation

    private func estimateTokens(for messages: [GroqMessage]) -> Int {
        let totalChars = messages.reduce(0) { $0 + $1.content.count }
        return max(1, totalChars / 4)
    }
}
