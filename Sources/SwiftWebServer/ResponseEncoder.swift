import Foundation

public struct ResponseEncoder: Sendable {
    public init() {}

    public func encode(_ response: Response, for request: Request) throws -> Data {
        var data = Data()

        let statusLine = "HTTP/1.1 \(response.status.code) \(response.status.reasonPhrase)\r\n"
        data.append(Data(statusLine.utf8))

        var headers = response.headers

        var bodyData = try collectBodyData(from: response.body)
        let isHead = request.method == .head
        if isHead {
            headers.set(name: "Content-Length", value: String(bodyData.count))
            bodyData = Data()
        } else if headers["Content-Length"] == nil {
            headers.set(name: "Content-Length", value: String(bodyData.count))
        }

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
