import Foundation

/// Log level for messages emitted by `WebServer`.
public enum LogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

/// A closure that receives log messages from `WebServer`.
///
/// The first argument is the log level; the second is the formatted message.
public typealias LogHandler = @Sendable (LogLevel, String) -> Void
