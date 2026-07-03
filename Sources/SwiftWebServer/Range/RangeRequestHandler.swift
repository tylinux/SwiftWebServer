import Foundation

public struct ByteRange: Sendable {
    public let start: Int
    public let end: Int

    public init(_ string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("bytes=") else {
            throw RangeError.invalidRange
        }
        let rangeString = String(trimmed.dropFirst("bytes=".count))
        let parts = rangeString.split(separator: "-").map(String.init)
        guard parts.count == 2,
              let start = Int(parts[0]),
              let end = Int(parts[1]) else {
            throw RangeError.invalidRange
        }
        self.start = start
        self.end = end
    }

    public func isValid(for totalLength: Int) -> Bool {
        start >= 0 && end < totalLength && start <= end
    }

    public var length: Int {
        end - start + 1
    }
}

public enum RangeError: Error, Sendable {
    case invalidRange
}
