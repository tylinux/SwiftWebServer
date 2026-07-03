import Foundation

public enum ResponseBody: Sendable {
    case empty
    case data(Data)
    case file(URL)
}

public struct Response: Sendable {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ResponseBody

    public init(status: HTTPStatus = .ok, headers: HTTPHeaders = HTTPHeaders(), body: ResponseBody = .empty) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public init(text: String) {
        let data = text.data(using: .utf8) ?? Data()
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: "text/plain; charset=utf-8")
        self.init(status: .ok, headers: headers, body: .data(data))
    }

    public init(text: String, status: HTTPStatus) {
        var response = Response(text: text)
        response.status = status
        self = response
    }

    public init(data: Data, contentType: String) {
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: contentType)
        self.init(status: .ok, headers: headers, body: .data(data))
    }

    public init(file url: URL) {
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: url.pathExtension.mimeType)
        self.init(status: .ok, headers: headers, body: .file(url))
    }

    public func status(_ status: HTTPStatus) -> Response {
        var copy = self
        copy.status = status
        return copy
    }

    public var dataBody: Data? {
        switch body {
        case .data(let data): data
        case .empty: Data()
        case .file: nil
        }
    }

    public var stringBody: String? {
        guard let data = dataBody else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension String {
    fileprivate var mimeType: String {
        switch self.lowercased() {
        case "html": "text/html"
        case "css": "text/css"
        case "js": "application/javascript"
        case "json": "application/json"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "pdf": "application/pdf"
        case "txt": "text/plain"
        default: "application/octet-stream"
        }
    }
}
