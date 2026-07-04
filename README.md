# SwiftWebServer

A modern Swift 6 embedded HTTP/1.1 WebServer framework for iOS, iPadOS, macOS, tvOS, and visionOS.

Inspired by [GCDWebServer](https://github.com/swisspol/GCDWebServer), rebuilt with `Network.framework`, `async/await`, and Swift 6 strict concurrency.

## Features

- HTTP/1.1 server with async handler API
- Strongly typed `Request` / `Response`
- Path parameter routing (`/files/:name`)
- gzip compression
- HTTP Range requests
- `multipart/form-data` parsing
- Basic and Digest authentication
- JSON request/response helpers

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

Or add it in Xcode via **File → Add Package Dependencies**.

## Quick Start

```swift
import SwiftWebServer

struct User: Codable {
    let name: String
}

let server = WebServer()

// `addRoute` is isolated to the `WebServer` actor, so call it with `await`.
await server.addRoute(method: .get, path: "/hello") { request in
    Response(text: "Hello, \(request.query["name"] ?? "world")!")
}

await server.addRoute(method: .post, path: "/api/user") { request in
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

## Demo

A multi-platform demo app is included in the `Demo/` folder. It contains Xcode targets for iOS, iPadOS, macOS, tvOS, and visionOS, and demonstrates starting a server, basic routing, JSON responses, and Basic authentication.

Open `Demo/SwiftWebServerDemo.xcodeproj` in Xcode, or regenerate it from `Demo/project.yml` with [xcodegen](https://github.com/yonaskolb/XcodeGen):

```bash
cd Demo
xcodegen generate
```

## Documentation

Full API reference is available via DocC in Xcode.

## License

MIT
