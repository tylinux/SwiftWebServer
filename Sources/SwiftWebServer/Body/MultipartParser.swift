import Foundation

public struct MultipartPart: Sendable {
    public let headers: HTTPHeaders
    public let name: String
    public let filename: String?
    public let body: Data

    public var stringValue: String? {
        String(data: body, encoding: .utf8)
    }
}

extension Request {
    public func multipartParts() throws -> [MultipartPart] {
        guard let contentType = headers["Content-Type"],
              contentType.lowercased().hasPrefix("multipart/form-data") else {
            throw MultipartError.invalidContentType
        }

        let boundary = try extractBoundary(from: contentType)
        let delimiter = Data("\r\n--\(boundary)".utf8)
        let firstDelimiter = Data("--\(boundary)".utf8)

        var parts: [MultipartPart] = []

        // Find the first delimiter. It may appear at the very start of the body
        // as `--boundary`, or later as `\r\n--boundary`.
        var searchStart: Data.Index
        if body.starts(with: firstDelimiter) {
            searchStart = firstDelimiter.count
        } else if let firstRange = body.range(of: delimiter) {
            searchStart = firstRange.upperBound
        } else {
            throw MultipartError.missingBoundary
        }

        while true {
            // Check if this is the closing delimiter
            let remaining = body.subdata(in: searchStart..<body.endIndex)
            if remaining.starts(with: Data("--".utf8)) {
                break
            }

            // Strip leading CRLF after delimiter
            if remaining.starts(with: Data("\r\n".utf8)) {
                searchStart += 2
            }

            guard let nextDelimiterRange = body.range(of: delimiter, in: searchStart..<body.endIndex) else {
                break
            }

            var partData = body.subdata(in: searchStart..<nextDelimiterRange.lowerBound)

            // Strip trailing CRLF before next delimiter
            if partData.suffix(2) == Data("\r\n".utf8) {
                partData = partData.dropLast(2)
            }

            guard let blankLineRange = partData.range(of: Data("\r\n\r\n".utf8)) else {
                searchStart = nextDelimiterRange.upperBound
                continue
            }

            let headerData = partData.subdata(in: partData.startIndex..<blankLineRange.lowerBound)
            let bodyData = partData.subdata(in: blankLineRange.upperBound..<partData.endIndex)

            let partHeaders = parseHeaders(from: headerData)
            guard let disposition = partHeaders["Content-Disposition"],
                  let name = parseDispositionValue(disposition, key: "name") else {
                searchStart = nextDelimiterRange.upperBound
                continue
            }
            let filename = parseDispositionValue(disposition, key: "filename")

            parts.append(MultipartPart(headers: partHeaders, name: name, filename: filename, body: bodyData))
            searchStart = nextDelimiterRange.upperBound
        }

        return parts
    }

    private func extractBoundary(from contentType: String) throws -> String {
        let lowercased = contentType.lowercased()
        guard let boundaryParamRange = lowercased.range(of: "boundary=") else {
            throw MultipartError.missingBoundary
        }

        var value = String(contentType[boundaryParamRange.upperBound...])

        // Strip trailing parameters/semicolons
        if let semicolon = value.firstIndex(of: ";") {
            value = String(value[..<semicolon])
        }

        value = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes
        if value.hasPrefix("\"") && value.hasSuffix("\"") {
            value = String(value.dropFirst().dropLast())
        }

        guard !value.isEmpty else {
            throw MultipartError.missingBoundary
        }
        return value
    }

    private func parseHeaders(from data: Data) -> HTTPHeaders {
        var headers = HTTPHeaders()
        guard let string = String(data: data, encoding: .utf8) else { return headers }
        for line in string.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            headers.add(name: parts[0].trimmingCharacters(in: .whitespaces),
                        value: parts[1].trimmingCharacters(in: .whitespaces))
        }
        return headers
    }

    private func parseDispositionValue(_ disposition: String, key: String) -> String? {
        let pattern = "\\b\(key)\\s*=\\s*\"?([^\";\\s]+)\"?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: disposition, range: NSRange(disposition.startIndex..., in: disposition)) else {
            return nil
        }
        let range = Range(match.range(at: 1), in: disposition)!
        return String(disposition[range])
    }
}

public enum MultipartError: Error, Sendable {
    case invalidContentType
    case missingBoundary
}
