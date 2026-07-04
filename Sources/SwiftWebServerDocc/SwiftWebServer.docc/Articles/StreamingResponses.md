# Streaming Responses

For responses that are produced incrementally, use a stream body. The server automatically applies chunked transfer encoding when needed.

## Example

```swift
await server.addRoute(method: .get, path: "/stream") { request in
    let stream = AsyncThrowingStream<Data, Error> { continuation in
        Task {
            continuation.yield(Data("hello ".utf8))
            continuation.yield(Data("world".utf8))
            continuation.finish()
        }
    }

    return Response(
        stream: stream,
        headers: ["Content-Type": "text/plain"]
    )
}
```

Streams work with keep-alive and gzip compression just like regular data responses.
