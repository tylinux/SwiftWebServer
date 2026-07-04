import Foundation

public struct BasicAuthenticator: Authenticator {
    private let validator: @Sendable (String, String) -> Bool

    public init(validator: @escaping @Sendable (String, String) -> Bool) {
        self.validator = validator
    }

    public func authenticate(_ request: Request) -> AuthenticationResult {
        guard let header = request.headers["Authorization"],
              header.hasPrefix("Basic ") else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }

        let base64 = String(header.dropFirst("Basic ".count))
        guard let data = Data(base64Encoded: base64),
              let credentials = String(data: data, encoding: .utf8) else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }

        let parts = credentials.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }

        if validator(parts[0], parts[1]) {
            return .authenticated
        } else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }
    }
}
