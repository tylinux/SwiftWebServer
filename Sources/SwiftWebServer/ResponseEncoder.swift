import Foundation

public struct ResponseEncoder: Sendable {
    public init() {}

    public func encode(_ response: Response, for request: Request) throws -> Data {
        var data = Data()

        let statusLine = "HTTP/1.1 \(response.status.code) \(response.status.reasonPhrase)\r\n"
        data.append(Data(statusLine.utf8))

        var headers = response.headers

        let bodyData: Data
        switch response.body {
        case .empty:
            bodyData = Data()
        case .data(let d):
            bodyData = d
        case .file(let url):
            bodyData = try Data(contentsOf: url)
        }

        if headers["Content-Length"] == nil {
            headers.set(name: "Content-Length", value: String(bodyData.count))
        }

        for (name, value) in headers.allHeaderLines() {
            data.append(Data("\(name.headerNameTitleCased): \(value)\r\n".utf8))
        }

        data.append(Data("\r\n".utf8))
        data.append(bodyData)
        return data
    }
}

extension String {
    fileprivate var headerNameTitleCased: String {
        self.split(separator: "-").map { $0.capitalized }.joined(separator: "-")
    }
}
