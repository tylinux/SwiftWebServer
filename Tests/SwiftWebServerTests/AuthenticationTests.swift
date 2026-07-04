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

    @Test
    func digestAuthenticatorIssuesChallenge() async {
        let auth = DigestAuthenticator(realm: "test") { _ in "5ebe2294ecd0e0f08eab7690d2a6ee69" }
        let request = Request(method: .get, path: "/admin")
        let result = await auth.authenticate(request)
        if case .denied(let header) = result {
            #expect(header.contains("Digest"))
            #expect(header.contains("realm=\"test\""))
        } else {
            Issue.record("Expected challenge")
        }
    }
}
