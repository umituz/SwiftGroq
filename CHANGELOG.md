# Changelog

All notable changes to this package are documented here.
Quality gate for every release: `swiftlint` clean + `swift build` + `swift test` green.
Consumers bind via SPM URL (`from:`) — releases follow strict SemVer.

## [1.1.0] — 2026-11-10

### Changed
- **Model catalog refreshed to Groq's current production lineup.** Added: `llama4_maverick` (meta-llama/llama-4-maverick-17b-128e-instruct), `gptOss120b` (openai/gpt-oss-120b), `gptOss20b` (openai/gpt-oss-20b), `qwen3_32b` (qwen/qwen3-32b), `kimiK2` (moonshotai/kimi-k2-instruct-0905); `llama4_scout` case renamed to the short form. Removed Groq-retired models: all llama-3.2 previews (incl. vision), mixtral-8x7b, gemma2-9b, deepseek-r1-distill. No fleet consumer pinned a removed case (verified by grep across all apps) — default stays `llama33_70b`, so existing integrations are behavior-identical.
- `GroqModel.visionDefault` added — vision requests should use `llama4_scout` (the old vision-preview models are shut down on Groq's side).
- `GroqRateLimiter` limits table aligned with the new catalog (free-tier defaults preserved; unknown models keep falling back to defaults).

## [1.0.7] — 2026

### Added
- `meta-llama/llama-4-scout-17b-16e-instruct` model case.

## [1.0.6] — 2026

### Added
- Multi-source API key resolver (`.any`), test-suite fixes.

## [1.0.5] — 2026

### Added
- Llama 4 Scout vision support (client-side wiring).

## [1.0.4] — 2026

### Added
- Vision API support (`chatWithVision` / `decodeWithVision`).

## [1.0.3] — 2026

Initial public lineup: chat + decoded chat + history + streaming (SSE),
rate limiter, retry policy, prompt sanitizer, security pinning helpers,
multi-source API key resolution (Info.plist / Keychain / environment).
