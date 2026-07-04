# Logging and Lifecycle

## Logging

Set a log handler to receive server events:

```swift
server.setLogHandler { level, message in
    print("[\(level.rawValue.uppercased())] \(message)")
}
```

The handler receives messages for server start/stop, requests, responses, errors, and lifecycle changes.

## Lifecycle

```swift
try await server.start(port: 8080)
await server.suspend()      // stop accepting new connections

try await server.resume()   // resume accepting connections
await server.stop()         // stop and close all connections
```

Use `suspend()` and `resume()` to handle app background/foreground transitions without rebuilding the route table.
