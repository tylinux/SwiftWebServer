# SwiftWebServer

A modern Swift 6 embedded HTTP/1.1 WebServer framework for iOS, iPadOS, macOS, tvOS, and visionOS.

Inspired by [GCDWebServer](https://github.com/swisspol/GCDWebServer), rebuilt with `Network.framework`, `async/await`, and Swift 6 strict concurrency.

## Features

- HTTP/1.1 server with async handler API
- Strongly typed `Request` / `Response`
- Path parameter routing (`/users/:id`, `/files/:path...` for nested static paths)
- Static file serving with directory-traversal protection
- gzip compression
- HTTP Range requests
- `application/x-www-form-urlencoded` parsing
- `multipart/form-data` parsing
- Basic and Digest authentication
- JSON request/response helpers
- Streaming / chunked responses
- Optional `SwiftWebServerWebUpload` module (file upload / list / download / delete)
- Logging with a custom handler
- Lifecycle management: start, stop, suspend, resume
- HTTP keep-alive
- HTTPS with a custom or bundled self-signed identity
- HTTP/2 ALPN negotiation is rejected with `505 HTTP Version Not Supported` (HTTP/1.1 only)

## Requirements

- Swift 6.0+
- iOS 17+ / iPadOS 17+ / macOS 14+ / tvOS 17+ / visionOS 1+

## Installation

Add the dependency to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tylinux/SwiftWebServer.git", from: "0.1.0")
]
```

Then add the products you need:

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "SwiftWebServer", package: "SwiftWebServer"),
    .product(name: "SwiftWebServerWebUpload", package: "SwiftWebServer"), // optional
])
```

Or add it in Xcode via **File → Add Package Dependencies**.

## Quick Start

```swift
import SwiftWebServer

let server = WebServer()

// `addRoute` is isolated to the `WebServer` actor, so call it with `await`.
await server.addRoute(method: .get, path: "/hello") { request in
    Response(text: "Hello, \(request.query["name"] ?? "world")!")
}

await server.addRoute(method: .post, path: "/api/user") { request in
    struct User: Codable {
        let name: String
    }
    let user: User = try request.decodeJSON()
    return try Response(json: ["id": 1, "name": user.name])
        .status(.created)
}

await server.addRoute(
    method: .get,
    path: "/admin",
    authenticator: Authentication.basic { username, password in
        username == "admin" && password == "secret"
    }
) { request in
    Response(text: "secret")
}

try await server.start(port: 8080)
```

## Form URL-encoded Bodies

Parse `application/x-www-form-urlencoded` request bodies:

```swift
await server.addRoute(method: .post, path: "/login") { request in
    let fields = try request.formFields()
    let username = fields["username"]
    return Response(text: "Hello, \(username ?? "guest")")
}
```

## Static Files

Serve files from a directory with optional index-file fallback:

```swift
import Foundation

let staticDirectory = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("public")

await server.addStaticFiles(
    at: "static",
    directory: staticDirectory,
    indexFile: "index.html"
)
```

Use a variadic path parameter (`:path...`) for nested paths:

```swift
await server.addRoute(method: .get, path: "/files/:path...") { request in
    guard let path = request.pathParameter("path") else {
        return Response(text: "Not found").status(.notFound)
    }
    return Response(text: "Requested: \(path)")
}
```

## Streaming / Chunked Responses

Return an `AsyncThrowingStream<Data, Error>` for long-running or incremental responses. The server automatically uses chunked transfer encoding:

```swift
await server.addRoute(method: .get, path: "/stream") { request in
    let stream = AsyncThrowingStream<Data, Error> { continuation in
        continuation.yield(Data("hello ".utf8))
        continuation.yield(Data("world".utf8))
        continuation.finish()
    }
    return Response(stream: stream, headers: ["Content-Type": "text/plain"])
}
```

## WebUpload (Optional)

Add a ready-to-use upload / list / download / delete endpoint:

```swift
import SwiftWebServerWebUpload

let uploadRoot = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)
    .first!
    .appendingPathComponent("Uploads")

let webUpload = WebUpload(
    server: server,
    rootDirectory: uploadRoot,
    // Optional: provide your own upload.html template.
    customIndexHTML: URL(fileURLWithPath: "/path/to/custom-upload.html")
)
await webUpload.configure()
```

The default page is available at `http://localhost:8080/upload`. The bundled HTML template uses `{{prefix}}` and `{{fileRows}}` placeholders; a custom template can use the same placeholders.

## Logging

Receive server log messages with a custom handler:

```swift
server.setLogHandler { level, message in
    print("[\(level.rawValue.uppercased())] \(message)")
}
```

## Lifecycle

Control the server lifecycle from your app:

```swift
try await server.start(port: 8080)   // start
await server.suspend()                // pause accepting new connections

try await server.resume()             // resume
await server.stop()                   // stop and close active connections
```

Useful for handling app background/foreground transitions.

## HTTPS

Start a TLS server with your own `SecIdentity`, or use the bundled self-signed identity for local testing:

```swift
import Security

let identity = try TLSIdentity.makeSelfSigned(host: "localhost")
let tlsConfig = TLSConfiguration(
    identity: identity,
    applicationProtocols: ["http/1.1"]
)

try await server.start(port: 8443, tls: tlsConfig)
```

In production, create a `SecIdentity` from your own certificate and pass it to `TLSConfiguration`.

## HTTP/2

SwiftWebServer is an HTTP/1.1 server. If a TLS client negotiates HTTP/2 via ALPN, the server responds with `505 HTTP Version Not Supported` and closes the connection.

## Demo

A multi-platform demo app is included in the `Demo/` folder. It contains Xcode targets for iOS, iPadOS, macOS, tvOS, and visionOS, and demonstrates:

- Starting, suspending, resuming, and stopping the server
- Basic routing and JSON responses
- Basic authentication
- WebUpload file uploads
- A native uploaded-file list

Generate the Xcode project with [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
cd Demo
xcodegen generate
open SwiftWebServerDemo.xcodeproj
```

## Documentation

Full API reference is available via DocC in Xcode. The DocC catalog includes articles on routing, handlers, and getting started.

## License

MIT
