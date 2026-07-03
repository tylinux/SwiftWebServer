public struct HTTPMethod: RawRepresentable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let get = HTTPMethod(rawValue: "GET")
    public static let post = HTTPMethod(rawValue: "POST")
    public static let put = HTTPMethod(rawValue: "PUT")
    public static let delete = HTTPMethod(rawValue: "DELETE")
    public static let head = HTTPMethod(rawValue: "HEAD")
    public static let options = HTTPMethod(rawValue: "OPTIONS")
    public static let patch = HTTPMethod(rawValue: "PATCH")
}

extension HTTPMethod: Hashable {
    public static func == (lhs: HTTPMethod, rhs: HTTPMethod) -> Bool {
        lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue.uppercased())
    }
}
