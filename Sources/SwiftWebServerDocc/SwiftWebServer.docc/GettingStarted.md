# Getting Started

Create a `WebServer`, add routes, and start it.

```swift
func startServer() async throws {
    let server = WebServer()
    await server.addRoute(method: .get, path: "/ping") { _ in
        Response(text: "pong")
    }
    try await server.start(port: 8080)
}
```
