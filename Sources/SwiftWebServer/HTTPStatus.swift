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

    public static let `continue` = HTTPStatus(code: 100)
    public static let ok = HTTPStatus(code: 200)
    public static let created = HTTPStatus(code: 201)
    public static let noContent = HTTPStatus(code: 204)
    public static let movedPermanently = HTTPStatus(code: 301)
    public static let found = HTTPStatus(code: 302)
    public static let notModified = HTTPStatus(code: 304)
    public static let badRequest = HTTPStatus(code: 400)
    public static let unauthorized = HTTPStatus(code: 401)
    public static let forbidden = HTTPStatus(code: 403)
    public static let notFound = HTTPStatus(code: 404)
    public static let methodNotAllowed = HTTPStatus(code: 405)
    public static let rangeNotSatisfiable = HTTPStatus(code: 416)
    public static let imATeapot = HTTPStatus(code: 418)
    public static let internalServerError = HTTPStatus(code: 500)
    public static let notImplemented = HTTPStatus(code: 501)
    public static let badGateway = HTTPStatus(code: 502)
    public static let serviceUnavailable = HTTPStatus(code: 503)
}
