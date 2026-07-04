import Foundation
import CryptoKit

public struct DigestAuthenticator: Authenticator {
    public let realm: String
    private let passwordHashForUser: @Sendable (String) -> String?
    private let nonceStore = NonceStore()

    public init(realm: String, passwordHashForUser: @escaping @Sendable (String) -> String?) {
        self.realm = realm
        self.passwordHashForUser = passwordHashForUser
    }

    public func authenticate(_ request: Request) async -> AuthenticationResult {
        guard let authorization = request.headers["Authorization"] else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }
        let scheme = String(authorization.prefix(while: { !$0.isWhitespace }))
        guard scheme.caseInsensitiveCompare("Digest") == .orderedSame else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        let params = parseDigestParams(String(authorization.dropFirst("Digest".count).trimmingCharacters(in: .whitespaces)))
        guard let username = params["username"],
              let nonce = params["nonce"],
              let uri = params["uri"],
              let response = params["response"],
              params["realm"]?.caseInsensitiveCompare(realm) == .orderedSame else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        guard await nonceStore.isValid(nonce) else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        guard let a1 = passwordHashForUser(username) else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        // RFC 2069 no-qop formula
        let a2 = md5("\(request.method.rawValue):\(uri)")
        let expected = md5("\(a1):\(nonce):\(a2)")

        if expected == response.lowercased() {
            return .authenticated
        } else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }
    }

    private func challengeHeader() async -> String {
        let nonce = await nonceStore.generate()
        return "Digest realm=\"\(realm)\", nonce=\"\(nonce)\", algorithm=MD5"
    }

    private func parseDigestParams(_ string: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = "([a-zA-Z]+)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return result }
        let nsRange = NSRange(string.startIndex..., in: string)
        for match in regex.matches(in: string, options: [], range: nsRange) {
            guard match.numberOfRanges == 3,
                  let keyRange = Range(match.range(at: 1), in: string),
                  let valueRange = Range(match.range(at: 2), in: string) else { continue }
            result[String(string[keyRange]).lowercased()] = String(string[valueRange])
        }
        return result
    }
}

private actor NonceStore {
    private var nonces: Set<String> = []

    func generate() -> String {
        let nonce = UUID().uuidString
        nonces.insert(nonce)
        return nonce
    }

    func isValid(_ nonce: String) -> Bool {
        nonces.contains(nonce)
    }
}

private func md5(_ string: String) -> String {
    let data = Data(string.utf8)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02hhx", $0) }.joined()
}
