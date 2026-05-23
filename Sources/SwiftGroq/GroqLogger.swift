import Foundation
import os.log

public enum GroqLogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: GroqLogLevel, rhs: GroqLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public final class GroqLogger: @unchecked Sendable {
    public static let shared = GroqLogger()

    private let logger: Logger
    private let lock = NSLock()
    private var _minimumLevel: GroqLogLevel

    public var minimumLevel: GroqLogLevel {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _minimumLevel
        }
        set {
            lock.lock()
            _minimumLevel = newValue
            lock.unlock()
        }
    }

    public init(
        subsystem: String = "com.umituz.swiftgroq",
        category: String = "GroqClient",
        minimumLevel: GroqLogLevel = .info
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self._minimumLevel = minimumLevel
    }

    private func shouldLog(_ level: GroqLogLevel) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _minimumLevel <= level
    }

    public func debug(_ message: @escaping @autoclosure () -> String) {
        guard shouldLog(.debug) else { return }
        logger.debug("\(message(), privacy: .private)")
    }

    public func info(_ message: @escaping @autoclosure () -> String) {
        guard shouldLog(.info) else { return }
        logger.info("\(message(), privacy: .private)")
    }

    public func warning(_ message: @escaping @autoclosure () -> String) {
        guard shouldLog(.warning) else { return }
        logger.warning("\(message(), privacy: .private)")
    }

    public func error(_ message: @escaping @autoclosure () -> String) {
        guard shouldLog(.error) else { return }
        logger.error("\(message(), privacy: .private)")
    }
}
