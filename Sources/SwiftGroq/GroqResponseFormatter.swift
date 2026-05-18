import Foundation

public enum GroqResponseFormatter {
    public static func stripMarkdownCodeBlocks(_ text: String) -> String {
        var result = text

        let patterns = ["```sql", "```json", "```python", "```swift", "```javascript", "```html", "```css", "```xml", "```yaml", "```toml", "```bash", "```sh", "```"]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func extractJSON(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") {
            return String(trimmed[start...end])
        }

        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        if let data = trimmed.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) {
            return trimmed
        }

        return nil
    }

    public static func cleanResponse(_ text: String) -> String {
        var result = stripMarkdownCodeBlocks(text)
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\r", with: "")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
