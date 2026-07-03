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

        guard let dashIndex = rangeString.firstIndex(of: "-"),
              dashIndex != rangeString.endIndex else {
            throw RangeError.invalidRange
        }

        let beforeDash = String(rangeString[..<dashIndex])
        let afterDashStart = rangeString.index(after: dashIndex)
        let afterDash = String(rangeString[afterDashStart...])

        if beforeDash.isEmpty {
            // Suffix range: bytes=-500
            guard let suffixLength = Int(afterDash),
                  suffixLength >= 0 else {
                throw RangeError.invalidRange
            }
            self.start = -suffixLength
            self.end = -1
        } else if afterDash.isEmpty {
            // Open-ended range: bytes=0-
            guard let start = Int(beforeDash),
                  start >= 0 else {
                throw RangeError.invalidRange
            }
            self.start = start
            self.end = -1
        } else {
            // Closed range: bytes=0-9
            guard let start = Int(beforeDash),
                  let end = Int(afterDash),
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
            // Suffix range
            resolvedStart = max(0, totalLength + start)
            resolvedEnd = totalLength - 1
        } else if end < 0 {
            // Open-ended range
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
