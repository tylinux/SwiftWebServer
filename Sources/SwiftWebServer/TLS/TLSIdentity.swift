import Foundation
import Security

public enum TLSIdentityError: Error, Sendable {
    case missingResource
    case importFailed(OSStatus)
    case identityNotFound
}

public enum TLSIdentity {
    /// Returns a self-signed identity bundled with the package for testing.
    ///
    /// The certificate is valid for `localhost`. In production, supply your own
    /// `SecIdentity` created from a trusted certificate.
    public static func makeSelfSigned(host: String = "localhost") throws -> SecIdentity {
        _ = host
        guard let url = Bundle.module.url(forResource: "selfsigned", withExtension: "p12") else {
            throw TLSIdentityError.missingResource
        }
        let data = try Data(contentsOf: url)
        let options: [String: String] = [kSecImportExportPassphrase as String: "swiftwebserver"]
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess else {
            throw TLSIdentityError.importFailed(status)
        }
        guard let dicts = items as? [[String: Any]],
              let identity = dicts.first?[kSecImportItemIdentity as String] as! SecIdentity? else {
            throw TLSIdentityError.identityNotFound
        }
        return identity
    }
}
