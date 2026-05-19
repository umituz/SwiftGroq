import Foundation

public enum GroqPromptSanitizer {
    private static let injectionPatterns: [(regex: NSRegularExpression, label: String)] = {
        let patterns: [(String, String)] = [
            ( #"ignore\s+(all\s+)?previous\s+instructions"#, "filtered" ),
            ( #"ignore\s+the\s+above"#, "filtered" ),
            ( #"disregard\s+(all\s+)?(previous\s+)?instructions"#, "filtered" ),
            ( #"forget\s+(your|all|previous)\s+instructions"#, "filtered" ),
            ( #"new\s+instructions\s*:"#, "filtered" ),
            ( #"system\s*:"#, "filtered" ),
            ( #"you\s+are\s+now"#, "filtered" ),
            ( #"act\s+as\s+(if\s+)?you\s+are"#, "filtered" ),
            ( #"pretend\s+you\s+are"#, "filtered" ),
            ( #"jailbreak"#, "filtered" ),
            ( #"developer\s+mode"#, "filtered" ),
            ( #"ignore\s+(all\s+)?safety\s+(guidelines|rules|instructions)"#, "filtered" ),
            ( #"bypass\s+(all\s+)?restrictions"#, "filtered" ),
        ]

        return patterns.compactMap { pattern, label in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
            return (regex, label)
        }
    }()

    public static func sanitize(_ input: String) -> String {
        var sanitized = removeControlCharacters(from: input)

        for pattern in injectionPatterns {
            let range = NSRange(sanitized.startIndex..., in: sanitized)
            let matches = pattern.regex.matches(in: sanitized, options: [], range: range)
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: sanitized) else { continue }
                sanitized.replaceSubrange(matchRange, with: "[\(pattern.label)]")
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
        return injectionPatterns.contains { pattern in
            pattern.regex.firstMatch(in: input, options: [], range: range) != nil
        }
    }

    private static func removeControlCharacters(from string: String) -> String {
        string.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }.map(String.init).joined()
    }
}
