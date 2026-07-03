# SwiftWebServer Design Spec

## Goal

Build a cross-platform Swift 6 embedded HTTP/1.1 WebServer framework for iOS, iPadOS, macOS, tvOS, and visionOS, inspired by [GCDWebServer](https://github.com/swisspol/GCDWebServer). The framework will use modern Swift concurrency (`async/await`), ship as a Swift Package Manager library, and include unit/integration tests plus comprehensive documentation (README + DocC).

## Scope

This release implements **feature set C**:

- Core HTTP/1.1 server with start/stop/lifecycle management
- Handler routing (exact match, path parameters, default handler)
- Strongly-typed `Request` / `Response`
- gzip compression
- HTTP Range requests for files
- `multipart/form-data` parsing
- Basic and Digest authentication
- JSON request/response body support

Out of scope for this release (recorded for future optimization):

- HTTP keep-alive connections
- HTTPS/TLS (transport supports it, but not exposed yet)
- Streaming multipart bodies (entire body read into memory)
- Full replay-attack protection in Digest auth
- Wildcard/regex routing beyond `:name`
- WebDAV / GCDWebUploader-style extensions

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| API style | Modern Swift 6 | `async/await`, actors, strongly-typed request/response |
| Transport | `Network.framework` | Native to Apple platforms, zero external dependencies, async-friendly |
| Package manager | Swift Package Manager | Cross-platform, Swift 6 native, CI-friendly |
| Minimum targets | iOS 17 / iPadOS 17 / macOS 14 / tvOS 17 / visionOS 1 | Unlock full Swift 6 concurrency features |
| Documentation | README + DocC | README for quick start, DocC for API reference |
| Testing | Swift Testing primary, XCTest for platform-specific cases | Best match for Swift 6, with XCTest fallback for platform binding verification |

## Architecture

The framework is organized around a small set of focused components:

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ TCP
       ▼
┌─────────────┐     accept      ┌─────────────┐
│  NWListener │ ──────────────▶ │  Connection │ (actor)
│  (WebServer)│                 │   (actor)   │
└─────────────┘                 └──────┬──────┘
                                       │
                                       ▼ read
                              ┌─────────────────┐
                              │  RequestParser  │
                              │  HTTP/1.1 parse │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │     Router      │
                              │ method+path     │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  User Handler   │
                              │ async (Request) │
                              │   throws -> Res │
                              └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  ResponseEncoder│
                              │ gzip/Range/chunk│
                              └────────┬────────┘
                                       │
                                       ▼ write
                              ┌─────────────────┐
                              │  NWConnection   │
                              │   send data     │
                              └─────────────────┘
```

### Core Types

| Type | Responsibility |
|------|----------------|
| `WebServer` | `actor`. Owns `NWListener`, route table, configuration, and lifecycle. |
| `Request` | `struct`. Parsed HTTP request: method, path, query, headers, body. |
| `Response` | `struct`. HTTP response: status, headers, body; builders for JSON/file/text. |
| `Route` | `struct`. A matching rule (method + path pattern) plus handler. |
| `Router` | `struct`. Matches `Request` to a `Route`. |
| `Connection` | `actor`. Wraps one `NWConnection`; read/parse/handle/encode/write. |
| `HTTPRequestParser` | Parses raw bytes into `Request`. |
| `ResponseEncoder` | Serializes `Response` into HTTP/1.1 bytes; applies gzip/Range. |

### Concurrency Model

- `WebServer` is an `actor`. All mutable server state lives there.
- Each accepted connection becomes its own `Connection` actor running in an independent `Task`.
- Handler signature: `async @Sendable (Request) throws -> Response`.
- Strict Swift 6 concurrency checking is enabled; all shared state crosses actor boundaries explicitly.

## Public API

### Quick Start

```swift
import SwiftWebServer

let server = WebServer()

server.addRoute(method: .get, path: "/hello") { request in
    Response(text: "Hello, \(request.query["name"] ?? "world")!")
}

server.addRoute(method: .post, path: "/api/user") { request in
    let user: User = try request.decodeJSON()
    return Response(json: ["id": 1, "name": user.name])
        .status(.created)
}

try await server.start(port: 8080)
```

### Authentication

```swift
server.addRoute(
    method: .get,
    path: "/admin",
    authentication: .basic { username, password in
        username == "admin" && password == secret
    }
) { request in
    Response(text: "secret")
}
```

### File Serving with Range and gzip

```swift
server.addRoute(method: .get, path: "/files/:name") { request in
    let fileURL = documentsDir.appendingPathComponent(request.pathParameter("name")!)
    return try Response(file: fileURL)
}
```

The encoder will automatically apply `Range` and `gzip` based on request headers.

## Feature Modules

### gzip Compression

- Triggered by `Accept-Encoding: gzip`.
- Uses `Compression` framework.
- Skipped for bodies smaller than 256 bytes.
- Sets `Content-Encoding: gzip` and recalculates `Content-Length`.

### Range Requests

- Supported in `Response(file:)`.
- Parses `bytes=start-end`.
- Returns `206 Partial Content` with `Content-Range` header.
- Invalid ranges return `416`.

### multipart/form-data

- `Request.multipartParts()` returns `[MultipartPart]`.
- Each part exposes `name`, `filename`, `headers`, and `body`.
- Simplified in-memory parsing for this release.

### Basic / Digest Authentication

- `Authenticator` protocol with `BasicAuthenticator` and `DigestAuthenticator`.
- Basic: decode `Authorization: Basic base64(user:pass)`.
- Digest: simplified RFC 7616 with nonce/realm hash verification.
- Failure returns `401 Unauthorized` + `WWW-Authenticate`.

### JSON Body

- `Request.decodeJSON<T: Decodable>(as:)`.
- `Response(json:)` sets `Content-Type: application/json`.

## Data Flow

1. `WebServer.start(port:)` creates an `NWListener` and begins accepting connections.
2. On each accepted `NWConnection`, spawn a `Connection` actor.
3. `Connection` reads bytes until a complete HTTP/1.1 request is available.
4. `HTTPRequestParser` converts bytes into a `Request`.
5. `Router` matches the request to a registered `Route` (or default handler).
6. The handler asynchronously produces a `Response`.
7. `ResponseEncoder` serializes the response, applying gzip/Range/chunked encoding as needed.
8. `Connection` writes the response bytes and closes the connection (no keep-alive in v1).

## Error Handling

- Parser errors return `400 Bad Request`.
- Router mismatches without a default handler return `404 Not Found`.
- Handler `throws` returns `500 Internal Server Error` with an optional error body.
- Authentication failures return `401`.
- Invalid ranges return `416`.

## Testing Strategy

| Test Layer | Framework | Examples |
|------------|-----------|----------|
| Unit | Swift Testing | Parser, Router, Encoder, Auth, Multipart, Range |
| Integration | Swift Testing | Start real server, use `URLSession` to hit endpoints |
| Platform | XCTest | Verify `NWListener` binds on each platform |
| Concurrency | Swift Testing | Multiple simultaneous requests, rapid start/stop cycles |

## Package Structure

```
SwiftWebServer/
├── Package.swift
├── README.md
├── Sources/
│   └── SwiftWebServer/
│       ├── WebServer.swift
│       ├── Connection.swift
│       ├── Request.swift
│       ├── Response.swift
│       ├── Route.swift
│       ├── Router.swift
│       ├── HTTPMethod.swift
│       ├── HTTPStatus.swift
│       ├── HTTPHeaders.swift
│       ├── HTTPRequestParser.swift
│       ├── ResponseEncoder.swift
│       ├── Authentication/
│       ├── Body/
│       ├── Compression/
│       └── Range/
├── Tests/
│   ├── SwiftWebServerTests/          # Swift Testing
│   └── SwiftWebServerXCTests/        # XCTest platform tests
└── Sources/SwiftWebServerDocc/
    └── SwiftWebServer.docc/
```

## Known Simplifications & Future Optimizations

1. **No keep-alive**: Each response closes the connection. GCDWebServer also does not support keep-alive.
2. **In-memory multipart**: Large file uploads are held in memory. Future work can stream to disk.
3. **Simplified Digest auth**: Nonce counters and full replay protection are not implemented.
4. **No HTTPS/TLS exposed**: `Network.framework` supports TLS; future release can add `start(port:tlsOptions:)`.
5. **Limited routing**: Only `:name` path parameters. Future can add `**` wildcards and regex.

## Risks

| Risk | Mitigation |
|------|------------|
| `Network.framework` background behavior on iOS | Document limitation; same as GCDWebServer. |
| Swift 6 strict concurrency errors | Keep state inside actors; use `@Sendable` closures. |
| HTTP parser edge cases | Comprehensive parser unit tests + fuzz-style inputs. |
| Flaky integration tests on CI | Bind to port 0 and read assigned port; use local loopback. |

## Success Criteria

- [ ] `swift build` succeeds on macOS with Swift 6 language mode.
- [ ] `swift test` passes all unit and integration tests.
- [ ] README includes installation, quick start, feature list, and platform matrix.
- [ ] DocC builds without warnings and covers all public API.
- [ ] Example app or snippet demonstrates file serving + JSON + auth.
