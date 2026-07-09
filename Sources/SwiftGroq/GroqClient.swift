import Foundation

public final class GroqClient: @unchecked Sendable {
    private static let _lock = NSLock()
    private static var _configuredInstance: GroqClient?

    public static var isConfigured: Bool {
        _lock.lock()
        defer { _lock.unlock() }
        guard let instance = _configuredInstance else { return false }
        return !instance.configuration.apiKey.isEmpty
    }

    public static func configured() throws -> GroqClient {
        _lock.lock()
        defer { _lock.unlock() }
        guard let instance = _configuredInstance else {
            throw GroqError.notConfigured
        }
        return instance
    }

    private let configuration: GroqConfiguration
    private let rateLimiter: GroqRateLimiter
    private let retryPolicy: GroqRetryPolicy
    private let session: URLSession
    private let logger: GroqLogger

    deinit {
        session.invalidateAndCancel()
    }

    public init(
        configuration: GroqConfiguration,
        rateLimiter: GroqRateLimiter = .shared,
        retryPolicy: GroqRetryPolicy = .default,
        certificatePinner: GroqCertificatePinner? = nil,
        logger: GroqLogger = .shared
    ) {
        self.configuration = configuration
        self.rateLimiter = rateLimiter
        self.retryPolicy = retryPolicy
        self.logger = logger

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeoutInterval
        config.waitsForConnectivity = true

        if let pinner = certificatePinner {
            self.session = URLSession(configuration: config, delegate: pinner, delegateQueue: nil)
        } else {
            self.session = URLSession(configuration: config)
        }
    }

    public static func configure(
        _ configuration: GroqConfiguration,
        rateLimiter: GroqRateLimiter = .shared,
        retryPolicy: GroqRetryPolicy = .default,
        certificatePinner: GroqCertificatePinner? = nil,
        logger: GroqLogger = .shared
    ) {
        _lock.lock()
        let previousInstance = _configuredInstance
        _configuredInstance = GroqClient(
            configuration: configuration,
            rateLimiter: rateLimiter,
            retryPolicy: retryPolicy,
            certificatePinner: certificatePinner,
            logger: logger
        )
        _lock.unlock()

        previousInstance?.session.invalidateAndCancel()
        logger.info("GroqClient configured with model: \(configuration.defaultModel)")
    }

    public static func reset() {
        _lock.lock()
        let previousInstance = _configuredInstance
        _configuredInstance = nil
        _lock.unlock()

        previousInstance?.session.invalidateAndCancel()
        GroqLogger.shared.info("GroqClient reset")
    }

    public static func configure(
        apiKeySource: GroqAPIKeySource,
        model: GroqModel = .llama33_70b,
        temperature: Double = 0.7,
        maxTokens: Int = 1024,
        timeout: TimeInterval = 30.0,
        certificatePinner: GroqCertificatePinner? = nil
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
        configure(config, certificatePinner: certificatePinner)
    }

    // MARK: - Chat

    public func chat(
        messages: [GroqMessage],
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil,
        sanitizeInput: Bool = true
    ) async throws -> String {
        let response = try await rawChat(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            responseFormat: responseFormat,
            sanitizeInput: sanitizeInput
        )

        guard let text = response.text, !text.isEmpty else {
            throw GroqError.emptyResponse
        }
        return GroqResponseFormatter.cleanResponse(text)
    }

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

    public func systemChat(
        systemPrompt: String,
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil
    ) async throws -> String {
        try await chat(
            messages: [
                GroqMessage(role: .system, content: systemPrompt),
                GroqMessage(role: .user, content: userMessage)
            ],
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            responseFormat: responseFormat
        )
    }

    public func chatWithHistory(
        systemPrompt: String,
        history: [GroqMessage],
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil
    ) async throws -> String {
        var messages: [GroqMessage] = [GroqMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: history)
        messages.append(GroqMessage(role: .user, content: userMessage))

        return try await chat(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            responseFormat: responseFormat
        )
    }

    public func decodedChat<T: Decodable>(
        _ type: T.Type,
        systemPrompt: String,
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        try await decode(
            type,
            messages: [
                GroqMessage(role: .system, content: systemPrompt),
                GroqMessage(role: .user, content: userMessage)
            ],
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
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil,
        sanitizeInput: Bool = true
    ) async throws -> GroqChatResponse {
        try validateParameters(temperature: temperature, maxTokens: maxTokens, topP: topP)

        let resolvedModel = model ?? configuration.defaultModel
        let processedMessages = sanitizeInput
            ? messages.map { GroqMessage(role: $0.role, content: sanitizeMessageContent($0.content)) }
            : messages

        let request = GroqChatRequest(
            model: resolvedModel,
            messages: processedMessages,
            temperature: temperature ?? configuration.defaultTemperature,
            maxTokens: maxTokens ?? configuration.defaultMaxTokens,
            topP: topP ?? 1.0,
            responseFormat: responseFormat
        )

        return try await executeWithRetry(request, model: resolvedModel)
    }

    // MARK: - Streaming

    public func chatStream(
        messages: [GroqMessage],
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil,
        sanitizeInput: Bool = true
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try validateParameters(temperature: temperature, maxTokens: maxTokens, topP: topP)
                    let resolvedModel = model ?? configuration.defaultModel
                    let processedMessages = sanitizeInput
                        ? messages.map { GroqMessage(role: $0.role, content: sanitizeMessageContent($0.content)) }
                        : messages

                    let request = GroqChatRequest(
                        model: resolvedModel,
                        messages: processedMessages,
                        temperature: temperature ?? configuration.defaultTemperature,
                        maxTokens: maxTokens ?? configuration.defaultMaxTokens,
                        topP: topP ?? 1.0,
                        stream: true,
                        responseFormat: responseFormat
                    )

                    let tokenEstimate = estimateTokens(for: request.messages)
                    try await rateLimiter.waitForAvailability(model: resolvedModel, estimatedTokens: tokenEstimate)

                    let urlRequest = try buildURLRequest(from: request)
                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    try validateHTTPResponse(response, data: Data())

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        guard line.hasPrefix("data: ") else { continue }

                        let payload = String(line.dropFirst(6))
                        if payload.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                            break
                        }

                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(GroqStreamChunk.self, from: data),
                              let content = chunk.choices.first?.delta.content else {
                            continue
                        }

                        continuation.yield(content)
                    }

                    await rateLimiter.recordRequest(model: resolvedModel, tokenCount: tokenEstimate)
                    continuation.finish()
                } catch {
                    logger.error("Stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func systemStream(
        systemPrompt: String,
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil
    ) -> AsyncThrowingStream<String, Error> {
        chatStream(
            messages: [
                GroqMessage(role: .system, content: systemPrompt),
                GroqMessage(role: .user, content: userMessage)
            ],
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            responseFormat: responseFormat
        )
    }

    public func streamWithHistory(
        systemPrompt: String,
        history: [GroqMessage],
        userMessage: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        topP: Double? = nil,
        responseFormat: GroqResponseFormat? = nil
    ) -> AsyncThrowingStream<String, Error> {
        var messages: [GroqMessage] = [GroqMessage(role: .system, content: systemPrompt)]
        messages.append(contentsOf: history)
        messages.append(GroqMessage(role: .user, content: userMessage))

        return chatStream(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            topP: topP,
            responseFormat: responseFormat
        )
    }

    // MARK: - Private

    private func executeWithRetry(_ request: GroqChatRequest, model: String) async throws -> GroqChatResponse {
        var lastError: GroqError?
        logger.debug("Starting request for model: \(model), messages: \(request.messages.count)")

        for attempt in 0...retryPolicy.maxRetries {
            do {
                let tokenEstimate = estimateTokens(for: request.messages)
                try await rateLimiter.waitForAvailability(model: model, estimatedTokens: tokenEstimate)
                let response = try await performRequest(request)
                await rateLimiter.recordRequest(
                    model: model,
                    tokenCount: response.usage?.totalTokens ?? tokenEstimate
                )
                logger.info("Request completed: \(model), tokens: \(response.usage?.totalTokens ?? tokenEstimate)")
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
                    let maxAttempts = self.retryPolicy.maxRetries
                    let delayStr = String(format: "%.1f", delay)
                    let errorMsg = error.errorDescription ?? "unknown"
                    logger.warning(
                        "Retry \(attempt + 1)/\(maxAttempts) after \(delayStr)s: \(errorMsg)"
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                logger.error("Request failed: \(error.errorDescription ?? "unknown")")
                throw error
            }
        }

        logger.error("All retry attempts exhausted for model: \(model)")
        throw lastError ?? GroqError.invalidResponse
    }

    private func performRequest(_ request: GroqChatRequest) async throws -> GroqChatResponse {
        let urlRequest = try buildURLRequest(from: request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                logger.error("Request timed out")
                throw GroqError.requestTimedOut
            }
            logger.error("Network error: \(error.localizedDescription)")
            throw GroqError.networkError(error.localizedDescription)
        }

        try validateHTTPResponse(response, data: data)

        do {
            return try JSONDecoder().decode(GroqChatResponse.self, from: data)
        } catch {
            throw GroqError.decodingFailed(error)
        }
    }

    private func buildURLRequest(from request: GroqChatRequest) throws -> URLRequest {
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
            throw GroqError.invalidRequest("Failed to encode request body: \(error.localizedDescription)")
        }

        return urlRequest
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
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
        default:
            let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let errorMessage = message?["error"] as? [String: Any]
            let detail = errorMessage?["message"] as? String
            throw GroqError.serverError(statusCode: httpResponse.statusCode, message: detail)
        }
    }

    private func estimateTokens(for messages: [GroqMessage]) -> Int {
        let combinedText = messages.map { extractText(from: $0.content) }.joined()
        return GroqTokenEstimator.estimate(text: combinedText)
    }

    private func extractText(from content: MessageContent) -> String {
        switch content {
        case .text(let text):
            return text
        case .array(let contents):
            return contents.compactMap { $0.text }.joined()
        }
    }

    private func sanitizeMessageContent(_ content: MessageContent) -> MessageContent {
        switch content {
        case .text(let text):
            return .text(GroqPromptSanitizer.sanitize(text))
        case .array(let contents):
            return .array(contents.map { currentContent in
                if currentContent.text != nil {
                    return GroqVisionContent.text(GroqPromptSanitizer.sanitize(currentContent.text!))
                } else {
                    return currentContent // Don't sanitize image URLs
                }
            })
        }
    }

    private func validateParameters(temperature: Double?, maxTokens: Int?, topP: Double?) throws {
        if let temperature, temperature < 0 || temperature > 2 {
            throw GroqError.invalidRequest("Temperature must be between 0 and 2, got \(temperature)")
        }
        if let maxTokens, maxTokens <= 0 {
            throw GroqError.invalidRequest("maxTokens must be greater than 0, got \(maxTokens)")
        }
        if let topP, topP < 0 || topP > 1 {
            throw GroqError.invalidRequest("topP must be between 0 and 1, got \(topP)")
        }
    }

    // MARK: - Vision API

    /// Sends a vision request with image and text content
    public func chatWithVision(
        systemPrompt: String,
        userMessage: String,
        imageURL: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        responseFormat: GroqResponseFormat? = nil
    ) async throws -> String {
        let visionContents: [GroqVisionContent] = [
            .text(userMessage),
            .image(url: imageURL)
        ]

        let messages: [GroqMessage] = [
            GroqMessage(role: .system, content: systemPrompt),
            GroqMessage(role: .user, visionContents: visionContents)
        ]

        return try await chat(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat,
            sanitizeInput: false // Don't sanitize vision content
        )
    }

    /// Sends a vision request and decodes the response
    public func decodeWithVision<T: Decodable>(
        _ type: T.Type,
        systemPrompt: String,
        userMessage: String,
        imageURL: String,
        model: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> T {
        let visionContents: [GroqVisionContent] = [
            .text(userMessage),
            .image(url: imageURL)
        ]

        let messages: [GroqMessage] = [
            GroqMessage(role: .system, content: systemPrompt),
            GroqMessage(role: .user, visionContents: visionContents)
        ]

        return try await decode(
            type,
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens,
            sanitizeInput: false // Don't sanitize vision content
        )
    }
}
