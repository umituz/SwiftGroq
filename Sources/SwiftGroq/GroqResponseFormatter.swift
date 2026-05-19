import Foundation

public enum GroqResponseFormatter {
    public static func stripMarkdownCodeBlocks(_ text: String) -> String {
        var result = text

        let patterns = [
            "```sql", "```json", "```python", "```swift", "```javascript",
            "```html", "```css", "```xml", "```yaml", "```toml",
            "```bash", "```sh", "```typescript", "```java", "```c",
            "```cpp", "```ruby", "```go", "```rust", "```"
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func extractJSON(from text: String) -> String? {
        let stripped = stripMarkdownCodeBlocks(text)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)

        let objectRange = findBalancedBrackets(in: trimmed, open: "{", close: "}")
        let arrayRange = findBalancedBrackets(in: trimmed, open: "[", close: "]")

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
           let _ = try? JSONSerialization.jsonObject(with: data) {
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

    private static func findBalancedBrackets(in text: String, open: Character, close: Character) -> Range<String.Index>? {
        var depth = 0
        var inString = false
        var escape = false
        var openIndex: String.Index?
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]

            if escape {
                escape = false
                i = text.index(after: i)
                continue
            }

            if char == "\\" {
                escape = true
                i = text.index(after: i)
                continue
            }

            if char == "\"" {
                inString.toggle()
                i = text.index(after: i)
                continue
            }

            if !inString {
                if char == open {
                    if openIndex == nil { openIndex = i }
                    depth += 1
                }
                if char == close {
                    depth -= 1
                    if depth == 0, let start = openIndex {
                        let nextIndex = text.index(after: i)
                        return start..<nextIndex
                    }
                }
            }

            i = text.index(after: i)
        }

        return nil
    }
}
