import Foundation

public enum ParseResult: Equatable, Sendable {
    case needsMoreData
    case request(Request, remaining: Data)
}

public enum HTTPParserError: Error, Sendable {
    case invalidRequestLine
    case invalidEncoding
    case invalidContentLength
    case invalidHeader
}

public struct HTTPRequestParser: Sendable {
    private var buffer: Data

    public init() {
        self.buffer = Data()
    }

    public mutating func parse(_ data: Data) throws -> ParseResult {
        buffer.append(contentsOf: data)

        guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return .needsMoreData
        }

        let headerData = buffer.subdata(in: 0..<headerEndRange.upperBound)
        guard let headersString = String(data: headerData, encoding: .utf8) else {
            throw HTTPParserError.invalidEncoding
        }
        var lines = headersString.split(separator: "\r\n", omittingEmptySubsequences: false)

        guard let requestLine = lines.first else {
            throw HTTPParserError.invalidRequestLine
        }
        lines.removeFirst()
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }

        let requestParts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
        guard requestParts.count == 3, requestParts[2].hasPrefix("HTTP/") else {
            throw HTTPParserError.invalidRequestLine
        }

        let method = HTTPMethod(rawValue: String(requestParts[0]))
        let (path, query) = parse(pathAndQuery: String(requestParts[1]))
        let httpVersion = String(requestParts[2])

        var headers = HTTPHeaders()
        for line in lines {
            let headerParts = line.split(separator: ":", maxSplits: 1)
            guard headerParts.count == 2 else {
                throw HTTPParserError.invalidHeader
            }
            let name = String(headerParts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(headerParts[1]).trimmingCharacters(in: .whitespaces)
            headers.add(name: name, value: value)
        }

        let bodyStart = headerEndRange.upperBound
        let contentLengthString = headers["Content-Length"] ?? "0"
        guard let contentLength = Int(contentLengthString), contentLength >= 0 else {
            throw HTTPParserError.invalidContentLength
        }

        guard buffer.count >= bodyStart + contentLength else {
            return .needsMoreData
        }

        let bodyEnd = bodyStart + contentLength
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        let remaining = buffer.count > bodyEnd ? buffer.subdata(in: bodyEnd..<buffer.count) : Data()
        buffer = remaining

        let request = Request(
            method: method,
            path: path,
            query: query,
            headers: headers,
            body: body,
            pathParameters: [:],
            httpVersion: httpVersion
        )
        return .request(request, remaining: remaining)
    }

    private func parse(pathAndQuery: String) -> (path: String, query: [String: String]) {
        guard let separatorIndex = pathAndQuery.firstIndex(of: "?") else {
            return (pathAndQuery, [:])
        }
        let path = String(pathAndQuery[..<separatorIndex])
        let queryString = String(pathAndQuery[pathAndQuery.index(after: separatorIndex)...])
        var query: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                query[parts[0]] = parts[1].removingPercentEncoding
            } else if parts.count == 1 {
                query[parts[0]] = ""
            }
        }
        return (path, query)
    }
}
