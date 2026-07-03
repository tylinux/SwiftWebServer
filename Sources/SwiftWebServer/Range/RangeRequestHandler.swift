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

        if rangeString.contains(",") {
            // Multipart ranges not supported in v1
            throw RangeError.invalidRange
        }

        let parts = rangeString.split(separator: "-", omittingEmptySubsequences: false).map(String.init)

        if rangeString.hasPrefix("-") {
            // Suffix range: bytes=-500
            guard parts.count == 2,
                  let suffixLength = Int(parts[1]),
                  suffixLength > 0 else {
                throw RangeError.invalidRange
            }
            self.start = -suffixLength
            self.end = -1
        } else if rangeString.hasSuffix("-") {
            // Open-ended range: bytes=0-
            guard parts.count == 2,
                  let start = Int(parts[0]),
                  start >= 0 else {
                throw RangeError.invalidRange
            }
            self.start = start
            self.end = -1
        } else {
            // Closed range: bytes=0-9
            guard parts.count == 2,
                  let start = Int(parts[0]),
                  let end = Int(parts[1]),
                  start >= 0,
                  end >= 0,
                  start <= end else {
                throw RangeError.invalidRange
            }
            self.start = start
            self.end = end
        }
    }

    public func resolvedRange(for totalLength: Int) -> (start: Int, end: Int)? {
        let resolvedStart: Int
        let resolvedEnd: Int

        if start < 0 {
            resolvedStart = max(0, totalLength + start)
            resolvedEnd = totalLength - 1
        } else if end < 0 {
            resolvedStart = start
            resolvedEnd = totalLength - 1
        } else {
            resolvedStart = start
            resolvedEnd = end
        }

        guard resolvedStart >= 0 && resolvedEnd < totalLength && resolvedStart <= resolvedEnd else {
            return nil
        }
        return (resolvedStart, resolvedEnd)
    }
}

public enum RangeError: Error, Sendable {
    case invalidRange
}
