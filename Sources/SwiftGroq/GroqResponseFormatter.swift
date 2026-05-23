import Foundation

public enum GroqResponseFormatter {
    private static let codeBlockPattern: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(
            pattern: "```[a-zA-Z0-9+_\\-]*\\n?",
            options: [.caseInsensitive]
        ) else {
            fatalError("GroqResponseFormatter: Invalid codeBlockPattern regex")
        }
        return regex
    }()

    public static func stripMarkdownCodeBlocks(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let result = codeBlockPattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
        return result
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func extractJSON(from text: String) -> String? {
        let stripped = stripMarkdownCodeBlocks(text)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        let objectRange = findBalancedBrackets(
            in: trimmed, open: "{", close: "}"
        )
        let arrayRange = findBalancedBrackets(
            in: trimmed, open: "[", close: "]"
        )

        if let objRange = objectRange, let arrRange = arrayRange {
            if objRange.lowerBound <= arrRange.lowerBound {
                return String(trimmed[objRange])
            }
            return String(trimmed[arrRange])
        }

        if let objRange = objectRange {
            return String(trimmed[objRange])
        }

        if let arrRange = arrayRange {
            return String(trimmed[arrRange])
        }

        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return trimmed
        }

        return nil
    }

    public static func cleanResponse(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\r", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func findBalancedBrackets(
        in text: String,
        open: Character,
        close: Character
    ) -> Range<String.Index>? {
        var depth = 0
        var inString = false
        var escape = false
        var openIndex: String.Index?
        var cursor = text.startIndex

        while cursor < text.endIndex {
            let char = text[cursor]

            if escape {
                escape = false
                cursor = text.index(after: cursor)
                continue
            }

            if char == "\\" {
                escape = true
                cursor = text.index(after: cursor)
                continue
            }

            if char == "\"" {
                inString.toggle()
                cursor = text.index(after: cursor)
                continue
            }

            if !inString {
                if char == open {
                    if openIndex == nil { openIndex = cursor }
                    depth += 1
                }
                if char == close {
                    depth -= 1
                    if depth == 0, let start = openIndex {
                        let next = text.index(after: cursor)
                        return start..<next
                    }
                }
            }

            cursor = text.index(after: cursor)
        }

        return nil
    }
}
