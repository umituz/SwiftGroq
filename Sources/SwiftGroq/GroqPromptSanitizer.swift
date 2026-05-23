import Foundation

public enum GroqPromptSanitizer {
    private static let injectionPatterns: [NSRegularExpression] = {
        let patterns = [
            #"ignore\s+(all\s+)?previous\s+instructions"#,
            #"ignore\s+the\s+above"#,
            #"disregard\s+(all\s+)?(previous\s+)?instructions"#,
            #"forget\s+(your|all|previous)\s+instructions"#,
            #"new\s+instructions\s*:"#,
            #"(?:^|[\s.!?])system\s*:"#,
            #"you\s+are\s+now\s+(?:a\s+)?(?:unrestricted|unfiltered|admin|root|superuser|DAN)"#,
            #"act\s+as\s+(if\s+)?you\s+are"#,
            #"pretend\s+you\s+are"#,
            #"jailbreak"#,
            #"developer\s+mode"#,
            #"ignore\s+(all\s+)?safety\s+(guidelines|rules|instructions)"#,
            #"bypass\s+(all\s+)?restrictions"#,
        ]

        return patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }()

    public static func sanitize(_ input: String) -> String {
        var sanitized = removeControlCharacters(from: input)

        for regex in injectionPatterns {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            let matches = regex.matches(in: sanitized, options: [], range: range)
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: sanitized) else { continue }
                sanitized.replaceSubrange(matchRange, with: "[filtered]")
            }
        }

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func truncate(_ input: String, maxLength: Int = 4000) -> String {
        guard input.count > maxLength else { return input }
        return String(input.prefix(maxLength))
    }

    public static func containsInjectionAttempt(_ input: String) -> Bool {
        let range = NSRange(input.startIndex..., in: input)
        return injectionPatterns.contains { regex in
            regex.firstMatch(in: input, options: [], range: range) != nil
        }
    }

    private static func removeControlCharacters(from string: String) -> String {
        string.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }.map(String.init).joined()
    }
}
