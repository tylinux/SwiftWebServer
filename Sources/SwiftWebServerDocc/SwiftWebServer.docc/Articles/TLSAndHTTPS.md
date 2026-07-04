# TLS and HTTPS

SwiftWebServer can accept TLS connections using `Network.framework`.

## Self-signed identity for local testing

The package includes a self-signed PKCS#12 identity for testing. It is valid for `localhost`:

```swift
import SwiftWebServer
import Security

let identity = try TLSIdentity.makeSelfSigned(host: "localhost")
let tls = TLSConfiguration(
    identity: identity,
    applicationProtocols: ["http/1.1"]
)

try await server.start(port: 8443, tls: tls)
```

## Production identity

In production, load or create your own `SecIdentity` from a trusted certificate and pass it to ``TLSConfiguration``.

## HTTP/2

SwiftWebServer speaks HTTP/1.1 only. If a TLS client advertises and negotiates HTTP/2 via ALPN, the server responds with `505 HTTP Version Not Supported` and closes the connection.
