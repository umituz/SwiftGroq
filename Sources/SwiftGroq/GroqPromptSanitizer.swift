import Foundation

public enum GroqPromptSanitizer {
    private static let injectionPatterns: [String] = [
        "ignore previous instructions",
        "ignore all previous",
        "ignore the above",
        "disregard",
        "forget your instructions",
        "new instructions:",
        "system:",
        "you are now",
        "act as",
        "pretend you are",
        "jailbreak",
        "developer mode"
    ]

    public static func sanitize(_ input: String) -> String {
        var sanitized = input

        let lowered = sanitized.lowercased()
        for pattern in injectionPatterns where lowered.contains(pattern) {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "[filtered]",
                options: .caseInsensitive
            )
        }

        sanitized = sanitized.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }.map(String.init).joined()

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func truncate(_ input: String, maxLength: Int = 4000) -> String {
        guard input.count > maxLength else { return input }
        return String(input.prefix(maxLength))
    }

    public static func containsInjectionAttempt(_ input: String) -> Bool {
        let lowered = input.lowercased()
        return injectionPatterns.contains { lowered.contains($0) }
    }
}
