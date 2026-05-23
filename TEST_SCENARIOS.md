# SwiftGroq Test Scenarios

Production QA test scenarios for the SwiftGroq library.

---

## 1. Configuration

### 1.1 Direct API Key Configuration
| Field | Value |
|---|---|
| **Test Name** | Configure with direct API key |
| **Preconditions** | Valid Groq API key |
| **Steps** | 1. Call `GroqClient.configure(apiKeySource: .key("gsk_xxx"))` |
| | 2. Check `GroqClient.isConfigured` returns `true` |
| | 3. Call `try GroqClient.configured()` |
| **Expected** | Client instance returned, no errors |
| **Fail If** | `isConfigured` is false, throws `notConfigured` |

### 1.2 Environment Variable API Key
| Field | Value |
|---|---|
| **Test Name** | Configure from environment variable |
| **Preconditions** | `GROQ_API_KEY` environment variable set |
| **Steps** | 1. Call `GroqClient.configure(apiKeySource: .environment())` |
| **Expected** | Client configured successfully |
| **Fail If** | Throws `missingAPIKey` |

### 1.3 Info.plist API Key
| Field | Value |
|---|---|
| **Test Name** | Configure from Info.plist |
| **Preconditions** | `GROQ_API_KEY` entry exists in Info.plist |
| **Steps** | 1. Call `GroqClient.configure(apiKeySource: .infoPlist())` |
| **Expected** | Client configured successfully |
| **Fail If** | Throws `missingAPIKey` |

### 1.4 Keychain API Key
| Field | Value |
|---|---|
| **Test Name** | Configure from Keychain |
| **Preconditions** | API key saved to Keychain via `KeychainHelper.save()` |
| **Steps** | 1. Call `KeychainHelper.save(key: "com.umituz.swiftgroq", value: "gsk_xxx")` |
| | 2. Call `GroqClient.configure(apiKeySource: .keychain())` |
| **Expected** | Client configured successfully |
| **Fail If** | Throws `missingAPIKey` |

### 1.5 Empty API Key Rejection
| Field | Value |
|---|---|
| **Test Name** | Reject empty API key |
| **Preconditions** | None |
| **Steps** | 1. Call `GroqClient.configure(apiKeySource: .key(""))` |
| **Expected** | Throws `GroqError.missingAPIKey` |
| **Fail If** | No error thrown |

### 1.6 Reset Configuration
| Field | Value |
|---|---|
| **Test Name** | Reset clears configuration |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `GroqClient.configure(apiKeySource: .key("gsk_xxx"))` |
| | 2. Verify `GroqClient.isConfigured` is `true` |
| | 3. Call `GroqClient.reset()` |
| | 4. Verify `GroqClient.isConfigured` is `false` |
| **Expected** | Configuration fully cleared |
| **Fail If** | `isConfigured` remains true after reset |

### 1.7 Reconfigure
| Field | Value |
|---|---|
| **Test Name** | Reconfigure with new settings |
| **Preconditions** | Client already configured |
| **Steps** | 1. Configure with model A |
| | 2. Configure with model B |
| | 3. Make request using `configured()` |
| **Expected** | Uses model B, old session invalidated |
| **Fail If** | Uses model A or session leak |

---

## 2. Chat Completion

### 2.1 Basic Chat
| Field | Value |
|---|---|
| **Test Name** | Basic single-turn chat |
| **Preconditions** | Client configured with valid API key |
| **Steps** | 1. Create messages: `[GroqMessage(role: .user, content: "Say hello")]` |
| | 2. Call `client.chat(messages: messages)` |
| | 3. Verify response is non-empty string |
| **Expected** | Non-empty string response |
| **Fail If** | Empty response, throws error |

### 2.2 System Chat
| Field | Value |
|---|---|
| **Test Name** | System prompt + user message |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.systemChat(systemPrompt: "Reply only in French", userMessage: "Hello")` |
| **Expected** | Response in French |
| **Fail If** | Response not in expected language |

### 2.3 Chat with History
| Field | Value |
|---|---|
| **Test Name** | Multi-turn conversation with history |
| **Preconditions** | Client configured |
| **Steps** | 1. Create history: `[GroqMessage(role: .user, content: "My name is John"), GroqMessage(role: .assistant, content: "Hello John")]` |
| | 2. Call `client.chatWithHistory(systemPrompt: "Be helpful", history: history, userMessage: "What is my name?")` |
| **Expected** | Response mentions "John" |
| **Fail If** | Does not reference previous context |

### 2.4 Custom Model Selection
| Field | Value |
|---|---|
| **Test Name** | Chat with specific model |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.chat(messages: messages, model: GroqModel.llama31_8b.rawValue)` |
| **Expected** | Response from llama-3.1-8b-instant model |
| **Fail If** | Model not recognized or error |

### 2.5 Custom Temperature
| Field | Value |
|---|---|
| **Test Name** | Chat with temperature 0 |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.chat(messages: messages, temperature: 0.0)` twice |
| **Expected** | Deterministic, near-identical responses |
| **Fail If** | Wildly different responses |

### 2.6 Raw Chat Response Access
| Field | Value |
|---|---|
| **Test Name** | Access full response object |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.rawChat(messages: messages)` |
| | 2. Access `response.id`, `response.usage`, `response.choices` |
| **Expected** | Full `GroqChatResponse` with ID, usage stats, choices |
| **Fail If** | Missing fields, nil usage |

### 2.7 Input Sanitization
| Field | Value |
|---|---|
| **Test Name** | Injection prompt is sanitized |
| **Preconditions** | Client configured |
| **Steps** | 1. Create message with "ignore previous instructions" |
| | 2. Call `client.chat(messages: messages)` with `sanitizeInput: true` |
| **Expected** | Injection pattern sanitized, safe response |
| **Edge Case** | Verify `sanitizeInput: false` sends raw content |

### 2.8 JSON Decoding
| Field | Value |
|---|---|
| **Test Name** | Decode structured response |
| **Preconditions** | Client configured |
| **Steps** | 1. Define `struct Sentiment: Decodable { let label: String }` |
| | 2. Call `client.decode(Sentiment.self, messages: [...])` |
| **Expected** | Typed `Sentiment` object |
| **Fail If** | Throws `decodingFailed` |

### 2.9 Empty Response Handling
| Field | Value |
|---|---|
| **Test Name** | Handle empty AI response |
| **Preconditions** | Client configured |
| **Steps** | 1. Send request that might produce empty response |
| | 2. Verify `emptyResponse` error thrown if no content |
| **Expected** | `GroqError.emptyResponse` thrown |
| **Fail If** | Returns empty string silently |

---

## 3. Streaming

### 3.1 Basic Streaming
| Field | Value |
|---|---|
| **Test Name** | Stream chat response |
| **Preconditions** | Client configured |
| **Steps** | 1. Get stream from `client.chatStream(messages: messages)` |
| | 2. Iterate over `for try await chunk in stream` |
| | 3. Collect all chunks |
| **Expected** | Multiple string chunks received progressively |
| **Fail If** | Single monolithic response or no chunks |

### 3.2 System Stream
| Field | Value |
|---|---|
| **Test Name** | Stream with system prompt |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.systemStream(systemPrompt: "...", userMessage: "...")` |
| | 2. Iterate and collect |
| **Expected** | Streamed response with system context |

### 3.3 Stream Cancellation
| Field | Value |
|---|---|
| **Test Name** | Cancel active stream |
| **Preconditions** | Streaming in progress |
| **Steps** | 1. Start stream |
| | 2. After receiving first chunk, cancel Task |
| **Expected** | Stream stops, no more chunks |
| **Fail If** | Continues after cancellation |

### 3.4 Stream Error Handling
| Field | Value |
|---|---|
| **Test Name** | Stream network error |
| **Preconditions** | Network unstable |
| **Steps** | 1. Start stream |
| | 2. Disconnect network mid-stream |
| **Expected** | Stream throws error, not silent hang |
| **Fail If** | Infinite hang without error |

---

## 4. Error Handling

### 4.1 Unauthorized (Invalid API Key)
| Field | Value |
|---|---|
| **Test Name** | Invalid API key error |
| **Preconditions** | Invalid API key configured |
| **Steps** | 1. Configure with `apiKeySource: .key("invalid-key")` |
| | 2. Make chat request |
| **Expected** | Throws `GroqError.unauthorized` |
| **Recovery** | `error.recoverySuggestion` contains console.groq.com |
| **Retryable** | `error.isRetryable == false` |

### 4.2 Rate Limited
| Field | Value |
|---|---|
| **Test Name** | Rate limit error with retry-after |
| **Preconditions** | Rate limit exceeded |
| **Steps** | 1. Send many requests rapidly |
| | 2. Wait for rate limit response |
| **Expected** | Throws `GroqError.rateLimited(retryAfter: N)` |
| **Recovery** | Wait N seconds before retrying |
| **Retryable** | `error.isRetryable == true` |

### 4.3 Network Error
| Field | Value |
|---|---|
| **Test Name** | Network connectivity error |
| **Preconditions** | No internet connection |
| **Steps** | 1. Disable network |
| | 2. Make chat request |
| **Expected** | Throws `GroqError.networkError(...)` |
| **Retryable** | `error.isRetryable == true` |

### 4.4 Request Timeout
| Field | Value |
|---|---|
| **Test Name** | Request timeout |
| **Preconditions** | Very slow network |
| **Steps** | 1. Set timeout to 1 second |
| | 2. Send request on slow network |
| **Expected** | Throws `GroqError.requestTimedOut` |
| **Retryable** | `error.isRetryable == true` |

### 4.5 Server Error
| Field | Value |
|---|---|
| **Test Name** | Server 5xx error |
| **Preconditions** | Groq API experiencing issues |
| **Steps** | 1. Make request during outage |
| **Expected** | Throws `GroqError.serverError(statusCode: 5xx)` |
| **Retryable** | `error.isRetryable == true` |

### 4.6 Insufficient Quota
| Field | Value |
|---|---|
| **Test Name** | Quota exceeded error |
| **Preconditions** | Account quota depleted |
| **Steps** | 1. Make request after quota exhausted |
| **Expected** | Throws `GroqError.insufficientQuota` |
| **Recovery** | Upgrade plan suggestion |

### 4.7 Configuration Error Classification
| Field | Value |
|---|---|
| **Test Name** | Identify config vs runtime errors |
| **Preconditions** | None |
| **Steps** | 1. Check `.unauthorized.isConfigurationError == true` |
| | 2. Check `.networkError.isConfigurationError == false` |
| | 3. Check `.rateLimited.isConfigurationError == false` |
| **Expected** | Correct classification |

---

## 5. Retry Policy

### 5.1 Default Retry on Rate Limit
| Field | Value |
|---|---|
| **Test Name** | Auto-retry on rate limit |
| **Preconditions** | Default retry policy |
| **Steps** | 1. Send request that gets rate limited |
| | 2. Observe retry behavior |
| **Expected** | Retries up to 2 times with exponential backoff |

### 5.2 No Retry on Auth Error
| Field | Value |
|---|---|
| **Test Name** | No retry on authorization failure |
| **Preconditions** | Default retry policy |
| **Steps** | 1. Send request with invalid key |
| **Expected** | Immediate failure, no retry |

### 5.3 Aggressive Retry Policy
| Field | Value |
|---|---|
| **Test Name** | Aggressive policy retries more |
| **Preconditions** | Aggressive retry policy configured |
| **Steps** | 1. Configure with `retryPolicy: .aggressive` |
| | 2. Send request that fails |
| **Expected** | Up to 4 retries with longer delays |

### 5.4 No Retry Policy
| Field | Value |
|---|---|
| **Test Name** | Disable all retries |
| **Preconditions** | None retry policy |
| **Steps** | 1. Configure with `retryPolicy: .none` |
| | 2. Send request that fails |
| **Expected** | Immediate failure, zero retries |

---

## 6. Rate Limiting

### 6.1 Per-Minute Request Limit
| Field | Value |
|---|---|
| **Test Name** | Enforce request rate limit |
| **Preconditions** | Default rate limiter (30 req/min) |
| **Steps** | 1. Send 30+ requests rapidly |
| | 2. Observe rate limiter behavior |
| **Expected** | After 30 requests, `canMakeRequest` returns false |

### 6.2 Token-Based Limiting
| Field | Value |
|---|---|
| **Test Name** | Enforce token rate limit |
| **Preconditions** | Default rate limiter (12000 TPM) |
| **Steps** | 1. Send requests with large token counts |
| **Expected** | Rate limited when token threshold exceeded |

### 6.3 Model-Specific Limits
| Field | Value |
|---|---|
| **Test Name** | Different limits per model |
| **Preconditions** | None |
| **Steps** | 1. Check `ModelRateLimits.limit(for: .llama33_70b.rawValue)` |
| | 2. Check `ModelRateLimits.limit(for: .llama31_8b.rawValue)` |
| **Expected** | Different TPM limits per model tier |

### 6.4 Daily Reset
| Field | Value |
|---|---|
| **Test Name** | Daily request counter resets |
| **Preconditions** | Requests recorded today |
| **Steps** | 1. Record requests for a model |
| | 2. Wait for date change |
| | 3. Check daily count |
| **Expected** | Daily count reset to 0 |

### 6.5 Wait for Availability
| Field | Value |
|---|---|
| **Test Name** | Auto-wait when rate limited |
| **Preconditions** | Rate limit hit |
| **Steps** | 1. Exhaust rate limit |
| | 2. Call `waitForAvailability()` |
| **Expected** | Returns when slot available, or throws after 60s |

---

## 7. Security

### 7.1 Certificate Pinning
| Field | Value |
|---|---|
| **Test Name** | Pin certificates |
| **Preconditions** | Known certificate hashes |
| **Steps** | 1. Create `GroqCertificatePinner(host: "api.groq.com", pinnedHashes: ["valid-hash"])` |
| | 2. Configure client with pinner |
| | 3. Make request |
| **Expected** | Request succeeds with pinned certificates |
| **Fail If** | Connection refused with invalid hashes |

### 7.2 Empty Pin Bypass
| Field | Value |
|---|---|
| **Test Name** | Empty hashes allow system trust |
| **Preconditions** | Pinner with empty hashes |
| **Steps** | 1. Create pinner with empty hashes |
| | 2. Make request |
| **Expected** | Uses system certificate trust |

### 7.3 Prompt Sanitization
| Field | Value |
|---|---|
| **Test Name** | Detect injection attempts |
| **Preconditions** | None |
| **Steps** | 1. Test `"ignore previous instructions"` -> true |
| | 2. Test `"jailbreak"` -> true |
| | 3. Test `"What is 2+2?"` -> false |
| | 4. Test `"IGNORE PREVIOUS INSTRUCTIONS"` -> true (case-insensitive) |
| | 5. Test `"ignore  all  previous   instructions"` -> true (whitespace) |
| **Expected** | Correct detection for all patterns |

### 7.4 Input Truncation
| Field | Value |
|---|---|
| **Test Name** | Truncate very long inputs |
| **Preconditions** | Input > 4000 chars |
| **Steps** | 1. Call `GroqPromptSanitizer.truncate(longInput, maxLength: 4000)` |
| **Expected** | Output exactly 4000 characters |

### 7.5 Keychain Storage Security
| Field | Value |
|---|---|
| **Test Name** | Keychain stores securely |
| **Preconditions** | None |
| **Steps** | 1. `KeychainHelper.save(key: "test", value: "secret")` |
| | 2. `KeychainHelper.load(key: "test")` returns "secret" |
| | 3. `KeychainHelper.delete(key: "test")` |
| | 4. `KeychainHelper.load(key: "test")` returns nil |
| **Expected** | Save/load/delete cycle works correctly |
| **Security** | Item stored with `kSecAttrAccessibleAfterFirstUnlock` |

---

## 8. Response Processing

### 8.1 Markdown Code Block Stripping
| Field | Value |
|---|---|
| **Test Name** | Strip any language code blocks |
| **Preconditions** | None |
| **Steps** | 1. `stripMarkdownCodeBlocks("```python\nprint('hi')\n```")` |
| | 2. `stripMarkdownCodeBlocks("```json\n{...}\n```")` |
| | 3. `stripMarkdownCodeBlocks("```\ncode\n```")` |
| **Expected** | Code blocks removed, content preserved |

### 8.2 JSON Extraction
| Field | Value |
|---|---|
| **Test Name** | Extract JSON from mixed text |
| **Preconditions** | None |
| **Steps** | 1. Extract from "Result: `{\"a\": 1}`" |
| | 2. Extract from "Items: `[1, 2, 3]`" |
| | 3. Extract nested JSON |
| | 4. Return nil for non-JSON text |
| **Expected** | Correct JSON extraction |

### 8.3 Escape Sequence Handling
| Field | Value |
|---|---|
| **Test Name** | Clean escape sequences |
| **Preconditions** | None |
| **Steps** | 1. `cleanResponse("Line 1\\nLine 2\\r")` |
| **Expected** | Returns "Line 1\nLine 2" |

---

## 9. Token Estimation

### 9.1 Basic Estimation
| Field | Value |
|---|---|
| **Test Name** | Estimate tokens for text |
| **Preconditions** | None |
| **Steps** | 1. `GroqTokenEstimator.estimate(text: "Hello world")` |
| **Expected** | Returns ~2 (8 chars / 4) |

### 9.2 Request Usage Estimation
| Field | Value |
|---|---|
| **Test Name** | Estimate full request tokens |
| **Preconditions** | None |
| **Steps** | 1. Call `estimateRequest(systemPrompt:history:userMessage:)` |
| **Expected** | Sum of all input token estimates |

### 9.3 Full Usage with Response
| Field | Value |
|---|---|
| **Test Name** | Estimate complete exchange |
| **Preconditions** | None |
| **Steps** | 1. Call `estimateFullUsage(...)` with response |
| **Expected** | Input + output token estimates |

---

## 10. Logging

### 10.1 Log Level Filtering
| Field | Value |
|---|---|
| **Test Name** | Filter logs by minimum level |
| **Preconditions** | Logger created |
| **Steps** | 1. Set `minimumLevel = .error` |
| | 2. Call debug/info/warning |
| | 3. Call error |
| **Expected** | Only error logged to Console.app |

### 10.2 Custom Logger
| Field | Value |
|---|---|
| **Test Name** | Inject custom logger |
| **Preconditions** | None |
| **Steps** | 1. Create `GroqLogger(minimumLevel: .debug)` |
| | 2. Pass to `GroqClient.init(logger: myLogger)` |
| **Expected** | Uses custom logger for all output |

---

## 11. Thread Safety

### 11.1 Concurrent Configuration
| Field | Value |
|---|---|
| **Test Name** | Thread-safe configure/reset |
| **Preconditions** | Multiple threads |
| **Steps** | 1. Call configure from Thread A |
| | 2. Call reset from Thread B simultaneously |
| **Expected** | No crash, no data corruption |

### 11.2 Concurrent Requests
| Field | Value |
|---|---|
| **Test Name** | Multiple simultaneous requests |
| **Preconditions** | Client configured |
| **Steps** | 1. Launch 5 concurrent chat requests |
| | 2. All use same client instance |
| **Expected** | All complete successfully, no race conditions |

### 11.3 Actor-Based Rate Limiter
| Field | Value |
|---|---|
| **Test Name** | Rate limiter thread safety |
| **Preconditions** | None |
| **Steps** | 1. Access rate limiter from multiple tasks |
| | 2. Record and check requests concurrently |
| **Expected** | Consistent state, no data races |

---

## 12. Edge Cases

### 12.1 Very Long Prompt
| Field | Value |
|---|---|
| **Test Name** | Handle maximum length prompts |
| **Preconditions** | Client configured |
| **Steps** | 1. Send 4000+ character prompt |
| **Expected** | Either processes or truncates, no crash |

### 12.2 Empty Message Array
| Field | Value |
|---|---|
| **Test Name** | Empty messages array |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.chat(messages: [])` |
| **Expected** | Server error or empty response, handled gracefully |

### 12.3 Special Characters in Content
| Field | Value |
|---|---|
| **Test Name** | Unicode and special characters |
| **Preconditions** | Client configured |
| **Steps** | 1. Send message with emoji, CJK, RTL text |
| **Expected** | Properly encoded and decoded |

### 12.4 Max Tokens = 1
| Field | Value |
|---|---|
| **Test Name** | Minimal max tokens |
| **Preconditions** | Client configured |
| **Steps** | 1. Call `client.chat(messages: [...], maxTokens: 1)` |
| **Expected** | Very short response (single token) |

### 12.5 Temperature Extremes
| Field | Value |
|---|---|
| **Test Name** | Temperature 0.0 vs 2.0 |
| **Preconditions** | Client configured |
| **Steps** | 1. Send with `temperature: 0.0` -> deterministic |
| | 2. Send with `temperature: 2.0` -> very random |
| **Expected** | Behavior matches temperature parameter |

### 12.6 Malformed JSON Response
| Field | Value |
|---|---|
| **Test Name** | Decode handles malformed JSON |
| **Preconditions** | Client configured |
| **Steps** | 1. Request JSON response from model |
| | 2. If model returns malformed JSON |
| **Expected** | `GroqError.decodingFailed` thrown |

### 12.7 URLSession Invalidation
| Field | Value |
|---|---|
| **Test Name** | Old session invalidated on reconfigure |
| **Preconditions** | Client configured |
| **Steps** | 1. Configure client A |
| | 2. Make request (works) |
| | 3. Reconfigure to client B |
| | 4. Old session should be invalidated |
| **Expected** | No session leaks |

---

## 13. Offline Scenarios

### 13.1 No Network at Startup
| Field | Value |
|---|---|
| **Test Name** | Configure offline, fail on request |
| **Preconditions** | No network |
| **Steps** | 1. Configure client offline |
| | 2. Make request |
| **Expected** | `GroqError.networkError` thrown |

### 13.2 Network Loss During Request
| Field | Value |
|---|---|
| **Test Name** | Disconnect mid-request |
| **Preconditions** | Request in flight |
| **Steps** | 1. Start request |
| | 2. Disable network |
| **Expected** | Timeout or network error, auto-retry if configured |

### 13.3 Network Recovery
| Field | Value |
|---|---|
| **Test Name** | Retry after network recovery |
| **Preconditions** | Network restored |
| **Steps** | 1. Request fails due to network |
| | 2. Network restored |
| | 3. Retry succeeds |
| **Expected** | Successful response after recovery |

---

## 14. Loading States

### 14.1 Request Duration
| Field | Value |
|---|---|
| **Test Name** | Show loading during request |
| **Preconditions** | Client configured |
| **Steps** | 1. Set loading state before request |
| | 2. Make async request |
| | 3. Clear loading state on completion |
| **Expected** | Loading state covers entire request duration |

---

## Critical Risks

| Risk | Severity | Mitigation |
|---|---|---|
| API key exposed in memory | Medium | Key stored in Keychain when possible |
| Rate limiter data race | High | Actor-based isolation |
| URLSession leak | High | `invalidateAndCancel()` on reset/deinit |
| Prompt injection bypass | Medium | Pattern-based sanitizer + `containsInjectionAttempt()` check |
| Certificate pinning failure | Medium | Falls back to system trust when no hashes configured |
| Retry exhaustion | Low | Configurable retry policy with max attempts |
| Thread-unsafe static access | Medium | NSLock-protected singleton |

---

## Technical Debt

| Item | Priority | Notes |
|---|---|---|
| Token estimation uses char/4 heuristic | Low | Could use tiktoken for accuracy |
| No request cancellation for non-streaming | Medium | No `withTaskCancellationHandler` on regular chat |
| No request deduplication | Low | Same request sent twice creates two API calls |
| No response caching | Low | Identical prompts re-fetched every time |
| Rate limiter polling instead of event-driven | Low | 500ms polling interval in `waitForAvailability` |

---

## Production Release Readiness Checklist

- [ ] All 120 unit tests passing
- [ ] Tested with valid API key on all 9 models
- [ ] Rate limiting verified under load
- [ ] Certificate pinning tested with valid and invalid hashes
- [ ] Streaming tested with cancellation
- [ ] Error recovery verified for all error types
- [ ] Keychain save/load/delete cycle verified
- [ ] Memory leak test: configure/reset cycle 100x, check memory stable
- [ ] Thread safety: 50 concurrent requests, no crash
- [ ] Timeout handling verified with 1-second timeout
- [ ] Prompt sanitizer catches all 13 injection patterns
- [ ] JSON extraction handles nested structures
- [ ] Logging output verified in Console.app
- [ ] API key never logged or exposed in error messages
- [ ] Package builds for iOS 17+ and macOS 14+
- [ ] No compiler warnings
- [ ] Swift Tools Version 5.9 compatible
- [ ] Documentation (README) updated for new API surface
