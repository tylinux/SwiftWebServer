import Foundation

public struct BasicAuthenticator: Authenticator {
    public let realm: String
    private let validator: @Sendable (String, String) -> Bool

    public init(realm: String = "SwiftWebServer", validator: @escaping @Sendable (String, String) -> Bool) {
        self.realm = realm
        self.validator = validator
    }

    public func authenticate(_ request: Request) async -> AuthenticationResult {
        guard let header = request.headers["Authorization"] else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"\(realm)\"")
        }
        let scheme = String(header.prefix(while: { !$0.isWhitespace }))
        guard scheme.caseInsensitiveCompare("Basic") == .orderedSame else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"\(realm)\"")
        }

        let base64 = String(header.dropFirst("Basic".count).trimmingCharacters(in: .whitespaces))
        guard let data = Data(base64Encoded: base64),
              let credentials = String(data: data, encoding: .utf8) else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"\(realm)\"")
        }

        let parts = credentials.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"\(realm)\"")
        }

        if validator(parts[0], parts[1]) {
            return .authenticated
        } else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"\(realm)\"")
        }
    }
}
