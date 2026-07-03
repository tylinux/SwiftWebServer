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
              contentType.hasPrefix("multipart/form-data") else {
            throw MultipartError.missingBoundary
        }

        let boundaryPrefix = "boundary="
        guard let boundaryRange = contentType.range(of: boundaryPrefix) else {
            throw MultipartError.missingBoundary
        }
        var boundary = String(contentType[boundaryRange.upperBound...])
        boundary = boundary.trimmingCharacters(in: .whitespacesAndNewlines)

        let delimiter = Data("--\(boundary)".utf8)
        let endDelimiter = Data("--\(boundary)--".utf8)

        var parts: [MultipartPart] = []
        var searchStart = body.startIndex

        while true {
            guard let delimiterRange = body.range(of: delimiter, in: searchStart..<body.endIndex) else { break }
            searchStart = delimiterRange.upperBound

            if body.range(of: endDelimiter, in: delimiterRange.lowerBound..<body.endIndex)?.lowerBound == delimiterRange.lowerBound {
                break
            }

            guard let nextDelimiterRange = body.range(of: delimiter, in: searchStart..<body.endIndex) else { break }
            var partData = body.subdata(in: searchStart..<nextDelimiterRange.lowerBound)

            if partData.starts(with: Data("\r\n".utf8)) {
                partData = partData.dropFirst(2)
            }
            if partData.suffix(2) == Data("\r\n".utf8) {
                partData = partData.dropLast(2)
            }

            guard let blankLineRange = partData.range(of: Data("\r\n\r\n".utf8)) else { continue }
            let headerData = partData.subdata(in: 0..<blankLineRange.lowerBound)
            let bodyData = partData.subdata(in: blankLineRange.upperBound..<partData.endIndex)

            let headers = parseHeaders(from: headerData)
            guard let disposition = headers["Content-Disposition"],
                  let name = parseDispositionValue(disposition, key: "name") else {
                continue
            }
            let filename = parseDispositionValue(disposition, key: "filename")

            parts.append(MultipartPart(headers: headers, name: name, filename: filename, body: bodyData))
        }

        return parts
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
        let pattern = "\(key)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: disposition, range: NSRange(disposition.startIndex..., in: disposition)) else {
            return nil
        }
        let range = Range(match.range(at: 1), in: disposition)!
        return String(disposition[range])
    }
}

public enum MultipartError: Error, Sendable {
    case missingBoundary
}
