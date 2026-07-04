import Testing
import Foundation
import CryptoKit
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
    func basicAuthenticatorDeniesInvalidCredentials() async {
        let auth = BasicAuthenticator { username, password in
            username == "admin" && password == "secret"
        }
        let encoded = Data("admin:wrong".utf8).base64EncodedString()
        let request = Request(
            method: .get,
            path: "/admin",
            headers: HTTPHeaders([("Authorization", "Basic \(encoded)")]),
            body: Data()
        )
        let result = await auth.authenticate(request)
        #expect(result != .authenticated)
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
    func basicAuthenticatorIsCaseInsensitive() async {
        let auth = BasicAuthenticator { username, password in
            username == "admin" && password == "secret"
        }
        let encoded = Data("admin:secret".utf8).base64EncodedString()
        let request = Request(
            method: .get,
            path: "/admin",
            headers: HTTPHeaders([("Authorization", "basic \(encoded)")]),
            body: Data()
        )
        let result = await auth.authenticate(request)
        #expect(result == .authenticated)
    }

    @Test
    func digestAuthenticatorIssuesChallenge() async {
        let auth = DigestAuthenticator(realm: "test") { _ in "5ebe2294ecd0e0f08eab7690d2a6ee69" }
        let request = Request(method: .get, path: "/admin")
        let result = await auth.authenticate(request)
        if case .denied(let header) = result {
            #expect(header.contains("Digest"))
            #expect(header.contains("realm=\"test\""))
            #expect(!header.contains("qop"))
        } else {
            Issue.record("Expected challenge")
        }
    }

    @Test
    func digestAuthenticatorRoundTrip() async throws {
        let realm = "test"
        let username = "admin"
        let password = "secret"
        let passwordHash = md5("\(username):\(realm):\(password)")

        let auth = DigestAuthenticator(realm: realm) { user in
            user == username ? passwordHash : nil
        }

        // Get challenge
        let challengeResult = await auth.authenticate(Request(method: .get, path: "/admin"))
        let header = try #require(challengeResult.wwwAuthenticateHeader)
        let nonce = try #require(parseDigestParam(header, key: "nonce"))

        // Build response
        let uri = "/admin"
        let a2 = md5("GET:\(uri)")
        let responseHash = md5("\(passwordHash):\(nonce):\(a2)")
        let authHeader = "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(responseHash)\""

        let request = Request(
            method: .get,
            path: "/admin",
            headers: HTTPHeaders([("Authorization", authHeader)]),
            body: Data()
        )
        let result = await auth.authenticate(request)
        #expect(result == .authenticated)
    }

    @Test
    func digestAuthenticatorRejectsWrongRealm() async throws {
        let auth = DigestAuthenticator(realm: "test") { _ in "5ebe2294ecd0e0f08eab7690d2a6ee69" }
        let request = Request(
            method: .get,
            path: "/admin",
            headers: HTTPHeaders([("Authorization", "Digest username=\"admin\", realm=\"wrong\", nonce=\"abc\", uri=\"/\", response=\"def\"")]),
            body: Data()
        )
        let result = await auth.authenticate(request)
        #expect(result != .authenticated)
    }
}

private func md5(_ string: String) -> String {
    let data = Data(string.utf8)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02hhx", $0) }.joined()
}

private func parseDigestParam(_ header: String, key: String) -> String? {
    let pattern = "\(key)=\"([^\"]+)\""
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
          let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
          let range = Range(match.range(at: 1), in: header) else {
        return nil
    }
    return String(header[range])
}

extension AuthenticationResult {
    fileprivate var wwwAuthenticateHeader: String? {
        if case .denied(let header) = self { return header }
        return nil
    }
}
