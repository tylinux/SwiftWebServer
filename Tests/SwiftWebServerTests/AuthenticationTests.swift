import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct AuthenticationTests {
    @Test
    func basicAuthenticatorAcceptsValidCredentials() async {
        let auth = BasicAuthenticator { username, password in
            username == "admin" && password == "secret"
        }
        let encoded = Data("admin:secret".utf8).base64EncodedString()
        let request = Request(
            method: .get,
            path: "/admin",
            headers: HTTPHeaders([("Authorization", "Basic \(encoded)")]),
            body: Data()
        )
        let result = await auth.authenticate(request)
        #expect(result == .authenticated)
    }

    @Test
    func basicAuthenticatorDeniesMissingHeader() async {
        let auth = BasicAuthenticator { _, _ in true }
        let request = Request(method: .get, path: "/admin")
        let result = await auth.authenticate(request)
        if case .denied(let header) = result {
            #expect(header.hasPrefix("Basic"))
        } else {
            Issue.record("Expected denied")
        }
    }

}
