import Foundation
import Network
import Security

/// TLS configuration for ``WebServer``.
public struct TLSConfiguration: @unchecked Sendable {
    /// The server identity (certificate + private key) presented during the TLS handshake.
    public let identity: SecIdentity

    /// ALPN protocols advertised to clients. Defaults to `["http/1.1"]`.
    public let applicationProtocols: [String]

    public init(identity: SecIdentity, applicationProtocols: [String] = ["http/1.1"]) {
        self.identity = identity
        self.applicationProtocols = applicationProtocols
    }
}
