import Foundation

public struct ResponseEncoder: Sendable {
    public init() {}

    public func encode(_ response: Response, for request: Request) throws -> Data {
        try encode(response, for: request, honorRange: true)
    }

    private func encode(_ response: Response, for request: Request, honorRange: Bool) throws -> Data {
        var data = Data()

        var status = response.status
        var headers = response.headers
        var bodyData = try collectBodyData(from: response.body)

        let hasRange = request.headers["Range"] != nil

        if honorRange, let rangeHeader = request.headers["Range"] {
            if let range = try? ByteRange(rangeHeader) {
                if let resolved = range.resolvedRange(for: bodyData.count) {
                    let originalLength = bodyData.count
                    bodyData = bodyData.subdata(in: resolved.start..<resolved.end + 1)
                    headers.set(name: "Content-Range", value: "bytes \(resolved.start)-\(resolved.end)/\(originalLength)")
                    status = HTTPStatus.partialContent
                } else {
                    var errorResponse = Response(text: "Range Not Satisfiable").status(.rangeNotSatisfiable)
                    errorResponse.headers.set(name: "Content-Range", value: "bytes */\(bodyData.count)")
                    return try encode(errorResponse, for: request, honorRange: false)
                }
            }
        }

        let acceptsGzip = (request.headers["Accept-Encoding"] ?? "").contains("gzip")
        if acceptsGzip && !hasRange && bodyData.count > 256 {
            bodyData = try GzipCompressor.compress(bodyData)
            headers.set(name: "Content-Encoding", value: "gzip")
        }

        let isHead = request.method == .head
        if isHead {
            headers.set(name: "Content-Length", value: String(bodyData.count))
            bodyData = Data()
        } else {
            headers.set(name: "Content-Length", value: String(bodyData.count))
        }

        let statusLine = "HTTP/1.1 \(status.code) \(status.reasonPhrase)\r\n"
        data.append(Data(statusLine.utf8))

        for (name, value) in headers.allHeaderLines() {
            data.append(Data("\(name): \(value)\r\n".utf8))
        }

        data.append(Data("\r\n".utf8))
        data.append(bodyData)
        return data
    }

    private func collectBodyData(from body: ResponseBody) throws -> Data {
        switch body {
        case .empty: return Data()
        case .data(let d): return d
        case .file(let url): return try Data(contentsOf: url)
        }
    }
}
