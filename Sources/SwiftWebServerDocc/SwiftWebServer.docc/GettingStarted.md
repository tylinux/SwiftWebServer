# Getting Started

Create a ``WebServer``, add routes, and start it.

## Basic server

```swift
import SwiftWebServer

func startServer() async throws {
    let server = WebServer()

    await server.addRoute(method: .get, path: "/ping") { _ in
        Response(text: "pong")
    }

    try await server.start(port: 8080)
}
```

All route handlers are `@Sendable` closures and run on the server's actor. They can be `async` and `throws`.

## Reading the request

```swift
await server.addRoute(method: .get, path: "/search") { request in
    let query = request.query["q"] ?? ""
    return Response(text: "Searching for \(query)")
}
```

## Stopping the server

```swift
await server.stop()
```

`stop()` closes the listener and all active connections. Use ``WebServer/suspend()`` and ``WebServer/resume()`` to temporarily pause the server without tearing it down.
