/// Represents an HTTP response status code and its associated reason phrase.
public struct HTTPStatus: Hashable, Sendable {
    public let code: Int

    /// Creates a status with the given HTTP status code.
    public init(code: Int) {
        self.code = code
    }

    /// The standard reason phrase for this status code, or an empty string if unknown.
    public var reasonPhrase: String {
        switch code {
        case 100: "Continue"
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 206: "Partial Content"
        case 301: "Moved Permanently"
        case 302: "Found"
        case 304: "Not Modified"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 416: "Range Not Satisfiable"
        case 418: "I'm a teapot"
        case 500: "Internal Server Error"
        case 501: "Not Implemented"
        case 502: "Bad Gateway"
        case 503: "Service Unavailable"
        default: ""
        }
    }

    /// HTTP 100 Continue.
    public static let `continue` = HTTPStatus(code: 100)
    /// HTTP 200 OK.
    public static let ok = HTTPStatus(code: 200)
    /// HTTP 201 Created.
    public static let created = HTTPStatus(code: 201)
    /// HTTP 204 No Content.
    public static let noContent = HTTPStatus(code: 204)
    /// HTTP 206 Partial Content.
    public static let partialContent = HTTPStatus(code: 206)
    /// HTTP 301 Moved Permanently.
    public static let movedPermanently = HTTPStatus(code: 301)
    /// HTTP 302 Found.
    public static let found = HTTPStatus(code: 302)
    /// HTTP 304 Not Modified.
    public static let notModified = HTTPStatus(code: 304)
    /// HTTP 400 Bad Request.
    public static let badRequest = HTTPStatus(code: 400)
    /// HTTP 401 Unauthorized.
    public static let unauthorized = HTTPStatus(code: 401)
    /// HTTP 403 Forbidden.
    public static let forbidden = HTTPStatus(code: 403)
    /// HTTP 404 Not Found.
    public static let notFound = HTTPStatus(code: 404)
    /// HTTP 405 Method Not Allowed.
    public static let methodNotAllowed = HTTPStatus(code: 405)
    /// HTTP 416 Range Not Satisfiable.
    public static let rangeNotSatisfiable = HTTPStatus(code: 416)
    /// HTTP 418 I'm a teapot.
    public static let imATeapot = HTTPStatus(code: 418)
    /// HTTP 500 Internal Server Error.
    public static let internalServerError = HTTPStatus(code: 500)
    /// HTTP 501 Not Implemented.
    public static let notImplemented = HTTPStatus(code: 501)
    /// HTTP 502 Bad Gateway.
    public static let badGateway = HTTPStatus(code: 502)
    /// HTTP 503 Service Unavailable.
    public static let serviceUnavailable = HTTPStatus(code: 503)
}
