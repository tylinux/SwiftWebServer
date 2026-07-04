import Foundation

public enum AuthenticationResult: Equatable, Sendable {
    case authenticated
    case denied(wwwAuthenticateHeader: String)
}

public protocol Authenticator: Sendable {
    func authenticate(_ request: Request) async -> AuthenticationResult
}

public enum Authentication {
    public static func basic(
        realm: String = "SwiftWebServer",
        validator: @escaping @Sendable (String, String) -> Bool
    ) -> any Authenticator {
        BasicAuthenticator(realm: realm, validator: validator)
    }

    public static func digest(
        realm: String,
        passwordHashForUser: @escaping @Sendable (String) -> String?
    ) -> any Authenticator {
        DigestAuthenticator(realm: realm, passwordHashForUser: passwordHashForUser)
    }
}
