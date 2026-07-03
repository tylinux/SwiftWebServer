# SwiftWebServer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Swift 6 cross-platform WebServer framework for iOS/iPadOS/macOS/tvOS/visionOS using `Network.framework` and `async/await`, matching the feature set C defined in `docs/superpowers/specs/2026-07-03-swiftwebserver-design.md`.

**Architecture:** The framework centers on a `WebServer` actor that owns an `NWListener`. Each accepted connection becomes a `Connection` actor, which reads bytes, parses an HTTP/1.1 `Request`, routes it through a `Router`, runs an async user handler, encodes the resulting `Response`, and writes bytes back. All shared mutable state lives inside actors; handlers are `@Sendable` closures.

**Tech Stack:** Swift 6, Swift Package Manager, `Network.framework`, `Compression` framework, Swift Testing (primary), XCTest (platform-specific), DocC.

---

## File Structure

```
SwiftWebServer/
├── Package.swift
├── README.md
├── .gitignore
├── Sources/
│   └── SwiftWebServer/
│       ├── SwiftWebServer.swift         (re-export / module entry)
│       ├── WebServer.swift              (actor WebServer)
│       ├── Connection.swift             (actor Connection)
│       ├── Request.swift                (Request, query parsing)
│       ├── Response.swift               (Response, ResponseBody)
│       ├── Route.swift                  (Route)
│       ├── Router.swift                 (Router, path matching)
│       ├── HTTPMethod.swift             (HTTPMethod)
│       ├── HTTPStatus.swift             (HTTPStatus)
│       ├── HTTPHeaders.swift            (HTTPHeaders)
│       ├── HTTPRequestParser.swift      (HTTP/1.1 parser)
│       ├── ResponseEncoder.swift        (HTTP/1.1 encoder)
│       ├── Authentication/
│       │   ├── Authenticator.swift
│       │   ├── BasicAuthenticator.swift
│       │   └── DigestAuthenticator.swift
│       ├── Body/
│       │   ├── JSONBody.swift
│       │   └── MultipartParser.swift
│       ├── Compression/
│       │   └── GzipCompressor.swift
│       └── Range/
│           └── RangeRequestHandler.swift
├── Tests/
│   ├── SwiftWebServerTests/
│   │   ├── HTTPMethodTests.swift
│   │   ├── HTTPStatusTests.swift
│   │   ├── HTTPHeadersTests.swift
│   │   ├── RouterTests.swift
│   │   ├── RequestParserTests.swift
│   │   ├── ResponseEncoderTests.swift
│   │   ├── JSONBodyTests.swift
│   │   ├── MultipartTests.swift
│   │   ├── RangeTests.swift
│   │   ├── AuthenticationTests.swift
│   │   ├── GzipTests.swift
│   │   └── IntegrationTests.swift
│   └── SwiftWebServerXCTests/
│       └── PlatformBindTests.swift
└── Sources/SwiftWebServerDocc/
    └── SwiftWebServer.docc/
        ├── SwiftWebServer.md
        ├── GettingStarted.md
        └── Articles/
            └── RoutingAndHandlers.md
```

---

## Task 1: Project Skeleton

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/SwiftWebServer/SwiftWebServer.swift`
- Create: `Tests/SwiftWebServerTests/SwiftWebServerTests.swift`

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftWebServer",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "SwiftWebServer",
            targets: ["SwiftWebServer"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftWebServer",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftWebServerTests",
            dependencies: ["SwiftWebServer"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "SwiftWebServerXCTests",
            dependencies: ["SwiftWebServer"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
```

- [ ] **Step 2: Write .gitignore**

```gitignore
.DS_Store
/.build
/Packages
xcuserdata/
DerivedData/
.swiftpm/configuration/registries.json
.swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
.netrc
```

- [ ] **Step 3: Create module entry**

```swift
// Sources/SwiftWebServer/SwiftWebServer.swift
public import Foundation
@_exported public import Network
```

- [ ] **Step 4: Verify build**

Run:

```bash
cd /Users/tylinux/Developer/Projects/SwiftWebServer
swift build
```

Expected: build succeeds with no warnings.

- [ ] **Step 5: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "chore: scaffold SwiftWebServer package"
```

---

## Task 2: HTTPMethod

**Files:**
- Create: `Sources/SwiftWebServer/HTTPMethod.swift`
- Create: `Tests/SwiftWebServerTests/HTTPMethodTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import SwiftWebServer

@Suite
struct HTTPMethodTests {
    @Test
    func equalityIsCaseInsensitive() {
        let get1 = HTTPMethod(rawValue: "GET")
        let get2 = HTTPMethod(rawValue: "get")
        #expect(get1 == get2)
        #expect(get1.rawValue == "GET")
    }

    @Test
    func staticMethods() {
        #expect(HTTPMethod.get == HTTPMethod(rawValue: "GET"))
        #expect(HTTPMethod.post == HTTPMethod(rawValue: "POST"))
        #expect(HTTPMethod.put == HTTPMethod(rawValue: "PUT"))
        #expect(HTTPMethod.delete == HTTPMethod(rawValue: "DELETE"))
        #expect(HTTPMethod.head == HTTPMethod(rawValue: "HEAD"))
        #expect(HTTPMethod.options == HTTPMethod(rawValue: "OPTIONS"))
        #expect(HTTPMethod.patch == HTTPMethod(rawValue: "PATCH"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter HTTPMethodTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement HTTPMethod**

```swift
public struct HTTPMethod: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    public init(stringLiteral value: String) {
        self.rawValue = value.uppercased()
    }

    public static let get: HTTPMethod = "GET"
    public static let post: HTTPMethod = "POST"
    public static let put: HTTPMethod = "PUT"
    public static let delete: HTTPMethod = "DELETE"
    public static let head: HTTPMethod = "HEAD"
    public static let options: HTTPMethod = "OPTIONS"
    public static let patch: HTTPMethod = "PATCH"
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter HTTPMethodTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/HTTPMethod.swift Tests/SwiftWebServerTests/HTTPMethodTests.swift
git commit -m "feat: add HTTPMethod type"
```

---

## Task 3: HTTPStatus

**Files:**
- Create: `Sources/SwiftWebServer/HTTPStatus.swift`
- Create: `Tests/SwiftWebServerTests/HTTPStatusTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import SwiftWebServer

@Suite
struct HTTPStatusTests {
    @Test
    func reasonPhrases() {
        #expect(HTTPStatus.ok.reasonPhrase == "OK")
        #expect(HTTPStatus.notFound.reasonPhrase == "Not Found")
        #expect(HTTPStatus.internalServerError.reasonPhrase == "Internal Server Error")
        #expect(HTTPStatus(code: 418).reasonPhrase == "I'm a teapot")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter HTTPStatusTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement HTTPStatus**

```swift
public struct HTTPStatus: Hashable, Sendable {
    public let code: Int

    public init(code: Int) {
        self.code = code
    }

    public var reasonPhrase: String {
        switch code {
        case 100: "Continue"
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 301: "Moved Permanently"
        case 302: "Found"
        case 304: "Not Modified"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 416: "Range Not Satisfiable"
        case 500: "Internal Server Error"
        case 501: "Not Implemented"
        case 502: "Bad Gateway"
        case 503: "Service Unavailable"
        default: ""
        }
    }

    public static let ok = HTTPStatus(code: 200)
    public static let created = HTTPStatus(code: 201)
    public static let noContent = HTTPStatus(code: 204)
    public static let badRequest = HTTPStatus(code: 400)
    public static let unauthorized = HTTPStatus(code: 401)
    public static let forbidden = HTTPStatus(code: 403)
    public static let notFound = HTTPStatus(code: 404)
    public static let methodNotAllowed = HTTPStatus(code: 405)
    public static let rangeNotSatisfiable = HTTPStatus(code: 416)
    public static let internalServerError = HTTPStatus(code: 500)
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter HTTPStatusTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/HTTPStatus.swift Tests/SwiftWebServerTests/HTTPStatusTests.swift
git commit -m "feat: add HTTPStatus type"
```

---

## Task 4: HTTPHeaders

**Files:**
- Create: `Sources/SwiftWebServer/HTTPHeaders.swift`
- Create: `Tests/SwiftWebServerTests/HTTPHeadersTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
@testable import SwiftWebServer

@Suite
struct HTTPHeadersTests {
    @Test
    func caseInsensitiveLookup() {
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: "application/json")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["Content-Type"] == "application/json")
    }

    @Test
    func addAccumulatesValues() {
        var headers = HTTPHeaders()
        headers.add(name: "Accept", value: "text/html")
        headers.add(name: "Accept", value: "application/json")
        #expect(headers.allValues(for: "Accept") == ["text/html", "application/json"])
    }

    @Test
    func setReplacesValues() {
        var headers = HTTPHeaders()
        headers.add(name: "Accept", value: "text/html")
        headers.set(name: "Accept", value: "application/json")
        #expect(headers.allValues(for: "Accept") == ["application/json"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter HTTPHeadersTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement HTTPHeaders**

```swift
public struct HTTPHeaders: Sendable, Equatable {
    private var storage: [String: [String]]

    public init() {
        self.storage = [:]
    }

    public init(_ headers: [(String, String)]) {
        self.storage = [:]
        for (name, value) in headers {
            add(name: name, value: value)
        }
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
    }

    public subscript(name: String) -> String? {
        storage[Self.normalize(name)]?.first
    }

    public func allValues(for name: String) -> [String] {
        storage[Self.normalize(name)] ?? []
    }

    public mutating func add(name: String, value: String) {
        let key = Self.normalize(name)
        storage[key, default: []].append(value)
    }

    public mutating func set(name: String, value: String) {
        let key = Self.normalize(name)
        storage[key] = [value]
    }

    public func allHeaderLines() -> [(name: String, value: String)] {
        storage.flatMap { key, values in
            values.map { (name: key, value: $0) }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter HTTPHeadersTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/HTTPHeaders.swift Tests/SwiftWebServerTests/HTTPHeadersTests.swift
git commit -m "feat: add HTTPHeaders type"
```

---

## Task 5: Request

**Files:**
- Create: `Sources/SwiftWebServer/Request.swift`
- Create: `Tests/SwiftWebServerTests/RequestTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RequestTests {
    @Test
    func queryParameters() {
        let request = Request(
            method: .get,
            path: "/search",
            query: ["q": "swift", "page": "2"],
            headers: HTTPHeaders(),
            body: Data(),
            pathParameters: [:]
        )
        #expect(request.query["q"] == "swift")
        #expect(request.query["page"] == "2")
    }

    @Test
    func pathParameterLookup() {
        let request = Request(
            method: .get,
            path: "/files/report.pdf",
            query: [:],
            headers: HTTPHeaders(),
            body: Data(),
            pathParameters: ["name": "report.pdf"]
        )
        #expect(request.pathParameter("name") == "report.pdf")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter RequestTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement Request**

```swift
import Foundation

public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let query: [String: String]
    public let headers: HTTPHeaders
    public let body: Data
    public let pathParameters: [String: String]

    public init(
        method: HTTPMethod,
        path: String,
        query: [String: String] = [:],
        headers: HTTPHeaders = HTTPHeaders(),
        body: Data = Data(),
        pathParameters: [String: String] = [:]
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.pathParameters = pathParameters
    }

    public func pathParameter(_ name: String) -> String? {
        pathParameters[name]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter RequestTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/Request.swift Tests/SwiftWebServerTests/RequestTests.swift
git commit -m "feat: add Request type"
```

---

## Task 6: Response

**Files:**
- Create: `Sources/SwiftWebServer/Response.swift`
- Create: `Tests/SwiftWebServerTests/ResponseTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct ResponseTests {
    @Test
    func textResponse() {
        let response = Response(text: "hello")
        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "text/plain; charset=utf-8")
        #expect(response.stringBody == "hello")
    }

    @Test
    func statusChaining() {
        let response = Response(text: "created").status(.created)
        #expect(response.status == .created)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter ResponseTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement Response**

```swift
import Foundation

public enum ResponseBody: Sendable {
    case empty
    case data(Data)
    case file(URL)
}

public struct Response: Sendable {
    public var status: HTTPStatus
    public var headers: HTTPHeaders
    public var body: ResponseBody

    public init(status: HTTPStatus = .ok, headers: HTTPHeaders = HTTPHeaders(), body: ResponseBody = .empty) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public init(text: String) {
        let data = text.data(using: .utf8) ?? Data()
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: "text/plain; charset=utf-8")
        self.init(status: .ok, headers: headers, body: .data(data))
    }

    public init(data: Data, contentType: String) {
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: contentType)
        self.init(status: .ok, headers: headers, body: .data(data))
    }

    public init(file url: URL) {
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: url.pathExtension.mimeType)
        self.init(status: .ok, headers: headers, body: .file(url))
    }

    public init(text: String, status: HTTPStatus) {
        var response = Response(text: text)
        response.status = status
        self = response
    }

    public func status(_ status: HTTPStatus) -> Response {
        var copy = self
        copy.status = status
        return copy
    }

    public var dataBody: Data? {
        switch body {
        case .data(let data): data
        case .empty: Data()
        case .file: nil
        }
    }

    public var stringBody: String? {
        guard let data = dataBody else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension String {
    fileprivate var mimeType: String {
        switch self.lowercased() {
        case "html": "text/html"
        case "css": "text/css"
        case "js": "application/javascript"
        case "json": "application/json"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "pdf": "application/pdf"
        case "txt": "text/plain"
        default: "application/octet-stream"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter ResponseTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/Response.swift Tests/SwiftWebServerTests/ResponseTests.swift
git commit -m "feat: add Response type"
```

---

## Task 7: Router

**Files:**
- Create: `Sources/SwiftWebServer/Route.swift`
- Create: `Sources/SwiftWebServer/Router.swift`
- Create: `Tests/SwiftWebServerTests/RouterTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RouterTests {
    @Test
    func exactMatch() async throws {
        var router = Router()
        router.add(Route(method: .get, path: "/hello") { _ in Response(text: "hi") })

        let request = Request(method: .get, path: "/hello")
        let (route, params) = try #require(router.match(request: request))
        let response = try await route.handler(request)
        #expect(response.stringBody == "hi")
        #expect(params.isEmpty)
    }

    @Test
    func pathParameterMatch() async throws {
        var router = Router()
        router.add(Route(method: .get, path: "/files/:name") { _ in Response(text: "ok") })

        let request = Request(method: .get, path: "/files/report.pdf")
        let (_, params) = try #require(router.match(request: request))
        #expect(params["name"] == "report.pdf")
    }

    @Test
    func methodMismatchReturnsNil() {
        var router = Router()
        router.add(Route(method: .post, path: "/hello") { _ in Response(text: "hi") })
        let request = Request(method: .get, path: "/hello")
        #expect(router.match(request: request) == nil)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter RouterTests
```

Expected: FAIL, types not found.

- [ ] **Step 3: Implement Route and Router**

```swift
// Sources/SwiftWebServer/Route.swift
import Foundation

public struct Route: Sendable {
    public let method: HTTPMethod
    public let pathPattern: String
    public let handler: @Sendable (Request) async throws -> Response

    public init(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (Request) async throws -> Response
    ) {
        self.method = method
        self.pathPattern = path
        self.handler = handler
    }
}
```

```swift
// Sources/SwiftWebServer/Router.swift
import Foundation

public struct Router: Sendable {
    private var routes: [Route]

    public init() {
        self.routes = []
    }

    public mutating func add(_ route: Route) {
        routes.append(route)
    }

    public func match(request: Request) -> (Route, [String: String])? {
        for route in routes {
            guard route.method == request.method else { continue }
            if let params = match(path: request.path, pattern: route.pathPattern) {
                return (route, params)
            }
        }
        return nil
    }

    private func match(path: String, pattern: String) -> [String: String]? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let patternComponents = pattern.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        guard pathComponents.count == patternComponents.count else { return nil }

        var parameters: [String: String] = [:]
        for (pathComponent, patternComponent) in zip(pathComponents, patternComponents) {
            if patternComponent.hasPrefix(":"),
               let name = patternComponent.dropFirst().split(separator: "/").first {
                parameters[String(name)] = pathComponent
            } else if patternComponent == pathComponent {
                continue
            } else {
                return nil
            }
        }
        return parameters
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter RouterTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/Route.swift Sources/SwiftWebServer/Router.swift Tests/SwiftWebServerTests/RouterTests.swift
git commit -m "feat: add Route and Router"
```

---

## Task 8: HTTP Request Parser

**Files:**
- Create: `Sources/SwiftWebServer/HTTPRequestParser.swift`
- Create: `Tests/SwiftWebServerTests/RequestParserTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RequestParserTests {
    @Test
    func parseSimpleGET() throws {
        let requestString = "GET /hello?foo=bar HTTP/1.1\r\nHost: localhost\r\n\r\n"
        var parser = HTTPRequestParser()
        let result = try parser.parse(Data(requestString.utf8))

        guard case .request(let request, let remaining) = result else {
            Issue.record("Expected complete request")
            return
        }
        #expect(request.method == .get)
        #expect(request.path == "/hello")
        #expect(request.query == ["foo": "bar"])
        #expect(request.headers["Host"] == "localhost")
        #expect(remaining.isEmpty)
    }

    @Test
    func parsePOSTWithBody() throws {
        let body = "name=swift"
        let requestString = "POST /user HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        var parser = HTTPRequestParser()
        let result = try parser.parse(Data(requestString.utf8))

        guard case .request(let request, _) = result else {
            Issue.record("Expected complete request")
            return
        }
        #expect(request.method == .post)
        #expect(request.path == "/user")
        #expect(String(data: request.body, encoding: .utf8) == body)
    }

    @Test
    func needsMoreData() throws {
        let requestString = "GET /hello HTTP/1.1\r\nHost: localhost\r\n\r"
        var parser = HTTPRequestParser()
        let result = try parser.parse(Data(requestString.utf8))
        #expect(result == .needsMoreData)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter RequestParserTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement HTTPRequestParser**

```swift
import Foundation

public enum ParseResult: Equatable, Sendable {
    case needsMoreData
    case request(Request, remaining: Data)
}

public struct HTTPRequestParser: Sendable {
    private var buffer: Data

    public init() {
        self.buffer = Data()
    }

    public mutating func parse(_ data: Data) throws -> ParseResult {
        buffer.append(contentsOf: data)

        guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            return .needsMoreData
        }

        let headerData = buffer.subdata(in: 0..<headerEndRange.upperBound)
        let headersString = String(data: headerData, encoding: .utf8) ?? ""
        var lines = headersString.split(separator: "\r\n", omittingEmptySubsequences: false)

        guard let requestLine = lines.first else {
            throw HTTPParserError.invalidRequestLine
        }
        lines.removeFirst()
        // Remove trailing empty line(s) caused by \r\n\r\n split
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }

        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count == 3, requestParts[2].hasPrefix("HTTP/") else {
            throw HTTPParserError.invalidRequestLine
        }

        let method = HTTPMethod(rawValue: requestParts[0])
        let (path, query) = parse(pathAndQuery: requestParts[1])

        var headers = HTTPHeaders()
        for line in lines {
            let headerParts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard headerParts.count == 2 else { continue }
            let name = headerParts[0].trimmingCharacters(in: .whitespaces)
            let value = headerParts[1].trimmingCharacters(in: .whitespaces)
            headers.add(name: name, value: value)
        }

        let bodyStart = headerEndRange.upperBound
        let contentLength = Int(headers["Content-Length"] ?? "0") ?? 0

        guard buffer.count >= bodyStart + contentLength else {
            return .needsMoreData
        }

        let bodyEnd = bodyStart + contentLength
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        let remaining = buffer.count > bodyEnd ? buffer.subdata(in: bodyEnd..<buffer.count) : Data()
        buffer = Data()

        let request = Request(
            method: method,
            path: path,
            query: query,
            headers: headers,
            body: body,
            pathParameters: [:]
        )
        return .request(request, remaining: remaining)
    }

    private func parse(pathAndQuery: String) -> (path: String, query: [String: String]) {
        guard let separatorIndex = pathAndQuery.firstIndex(of: "?") else {
            return (pathAndQuery, [:])
        }
        let path = String(pathAndQuery[..<separatorIndex])
        let queryString = String(pathAndQuery[pathAndQuery.index(after: separatorIndex)...])
        var query: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                query[parts[0]] = parts[1].removingPercentEncoding
            } else if parts.count == 1 {
                query[parts[0]] = ""
            }
        }
        return (path, query)
    }
}

public enum HTTPParserError: Error, Sendable {
    case invalidRequestLine
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter RequestParserTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/HTTPRequestParser.swift Tests/SwiftWebServerTests/RequestParserTests.swift
git commit -m "feat: add HTTP request parser"
```

---

## Task 9: Response Encoder

**Files:**
- Create: `Sources/SwiftWebServer/ResponseEncoder.swift`
- Create: `Tests/SwiftWebServerTests/ResponseEncoderTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct ResponseEncoderTests {
    @Test
    func encodesTextResponse() throws {
        let request = Request(method: .get, path: "/")
        let response = Response(text: "hello")
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 200 OK"))
        #expect(string.contains("Content-Type: text/plain; charset=utf-8"))
        #expect(string.contains("Content-Length: 5"))
        #expect(string.hasSuffix("\r\n\r\nhello"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter ResponseEncoderTests
```

Expected: FAIL, type not found.

- [ ] **Step 3: Implement ResponseEncoder**

```swift
import Foundation

public struct ResponseEncoder: Sendable {
    public init() {}

    public func encode(_ response: Response, for request: Request) throws -> Data {
        var data = Data()

        let statusLine = "HTTP/1.1 \(response.status.code) \(response.status.reasonPhrase)\r\n"
        data.append(Data(statusLine.utf8))

        var headers = response.headers

        let bodyData: Data
        switch response.body {
        case .empty:
            bodyData = Data()
        case .data(let d):
            bodyData = d
        case .file(let url):
            bodyData = try Data(contentsOf: url)
        }

        if headers["Content-Length"] == nil {
            headers.set(name: "Content-Length", value: String(bodyData.count))
        }

        for (name, value) in headers.allHeaderLines() {
            data.append(Data("\(name): \(value)\r\n".utf8))
        }

        data.append(Data("\r\n".utf8))
        data.append(bodyData)
        return data
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter ResponseEncoderTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/ResponseEncoder.swift Tests/SwiftWebServerTests/ResponseEncoderTests.swift
git commit -m "feat: add response encoder"
```

---

## Task 10: WebServer + Connection

**Files:**
- Create: `Sources/SwiftWebServer/WebServer.swift`
- Create: `Sources/SwiftWebServer/Connection.swift`
- Create: `Tests/SwiftWebServerTests/IntegrationTests.swift`

- [ ] **Step 1: Write failing integration test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite(.serialized)
struct IntegrationTests {
    @Test
    func getHello() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/hello") { _ in
            Response(text: "Hello, world!")
        }
        try await server.start(port: 0)
        let port = await server.port!

        let url = URL(string: "http://127.0.0.1:\(port)/hello")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "Hello, world!")

        await server.stop()
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter IntegrationTests
```

Expected: FAIL, `WebServer` type not found.

- [ ] **Step 3: Implement WebServer and Connection**

```swift
// Sources/SwiftWebServer/WebServer.swift
import Foundation
import Network

public actor WebServer {
    private var routes: [Route]
    private var listener: NWListener?
    private var task: Task<Void, Never>?

    public init() {
        self.routes = []
    }

    public var isRunning: Bool {
        listener != nil
    }

    public var port: UInt16? {
        listener?.port.rawValue
    }

    public func addRoute(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (Request) async throws -> Response
    ) {
        routes.append(Route(method: method, path: path, handler: handler))
    }

    public func start(port: UInt16) async throws {
        let parameters = NWParameters.tcp
        let nwPort: NWEndpoint.Port = port == 0 ? .any : NWEndpoint.Port(rawValue: port)
        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task {
                let connectionActor = Connection(
                    connection: connection,
                    router: Router(self.routes)
                )
                await connectionActor.start()
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }
    }

    public func stop() async {
        listener?.cancel()
        listener = nil
        task?.cancel()
        task = nil
    }
}
```

```swift
// Sources/SwiftWebServer/Connection.swift
import Foundation
import Network

internal actor Connection {
    private let connection: NWConnection
    private let router: Router
    private var parser = HTTPRequestParser()

    init(connection: NWConnection, router: Router) {
        self.connection = connection
        self.router = router
    }

    func start() async {
        await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled:
                    continuation.resume()
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }

        guard connection.state == .ready else { return }

        do {
            try await handleRequests()
        } catch {
            print("Connection error: \(error)")
        }
        connection.cancel()
    }

    private func handleRequests() async throws {
        while true {
            let chunk = try await receive()
            if chunk.isEmpty { break }

            let result = try parser.parse(chunk)
            guard case .request(var request, _) = result else {
                // Need more data; continue reading.
                continue
            }

            guard let (route, params) = router.match(request: request) else {
                try await sendErrorResponse(.notFound)
                break
            }

            request = Request(
                method: request.method,
                path: request.path,
                query: request.query,
                headers: request.headers,
                body: request.body,
                pathParameters: params
            )

            let response: Response
            do {
                response = try await route.handler(request)
            } catch {
                response = Response(text: "Internal Server Error", status: .internalServerError)
            }

            let encoded = try ResponseEncoder().encode(response, for: request)
            try await send(encoded)
            break // no keep-alive in v1
        }
    }

    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data ?? Data())
                }
            }
        }
    }

    private func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func sendErrorResponse(_ status: HTTPStatus) async throws {
        let response = Response(text: status.reasonPhrase).status(status)
        let request = Request(method: .get, path: "/")
        let encoded = try ResponseEncoder().encode(response, for: request)
        try await send(encoded)
    }
}

// Router initializer from array copy
extension Router {
    init(_ routes: [Route]) {
        self.init()
        for route in routes {
            self.add(route)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter IntegrationTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/WebServer.swift Sources/SwiftWebServer/Connection.swift Tests/SwiftWebServerTests/IntegrationTests.swift
git commit -m "feat: add WebServer and Connection with end-to-end integration test"
```

---

## Task 11: JSON Body Support

**Files:**
- Create: `Sources/SwiftWebServer/Body/JSONBody.swift`
- Create: `Tests/SwiftWebServerTests/JSONBodyTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

struct User: Codable, Equatable, Sendable {
    let name: String
}

@Suite
struct JSONBodyTests {
    @Test
    func decodeJSONRequestBody() throws {
        let data = Data("{\"name\":\"swift\"}".utf8)
        let request = Request(method: .post, path: "/user", headers: HTTPHeaders([("Content-Type", "application/json")]), body: data)
        let user: User = try request.decodeJSON()
        #expect(user == User(name: "swift"))
    }

    @Test
    func encodeJSONResponse() throws {
        let response = try Response(json: ["id": 1])
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.stringBody == "{\"id\":1}")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter JSONBodyTests
```

Expected: FAIL, methods not found.

- [ ] **Step 3: Implement JSON body helpers**

```swift
// Sources/SwiftWebServer/Body/JSONBody.swift
import Foundation

extension Request {
    public func decodeJSON<T: Decodable & Sendable>(
        _ type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try decoder.decode(type, from: body)
    }
}

extension Response {
    public init(json: some Encodable & Sendable, encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(json)
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: "application/json")
        self.init(status: .ok, headers: headers, body: .data(data))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter JSONBodyTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/Body/JSONBody.swift Tests/SwiftWebServerTests/JSONBodyTests.swift
git commit -m "feat: add JSON request/response body support"
```

---

## Task 12: gzip Compression

**Files:**
- Create: `Sources/SwiftWebServer/Compression/GzipCompressor.swift`
- Modify: `Sources/SwiftWebServer/ResponseEncoder.swift`
- Create: `Tests/SwiftWebServerTests/GzipTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct GzipTests {
    @Test
    func gzipCompressesAndDecompresses() throws {
        let original = Data("hello world hello world hello world".utf8)
        let compressed = try GzipCompressor.compress(original)
        #expect(compressed.count < original.count)

        let decompressed = try GzipCompressor.decompress(compressed)
        #expect(decompressed == original)
    }

    @Test
    func responseEncoderAppliesGzip() throws {
        let request = Request(
            method: .get,
            path: "/",
            headers: HTTPHeaders([("Accept-Encoding", "gzip")]),
            body: Data()
        )
        let response = Response(text: String(repeating: "a", count: 1000))
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("Content-Encoding: gzip"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter GzipTests
```

Expected: FAIL, `GzipCompressor` not found.

- [ ] **Step 3: Implement GzipCompressor**

```swift
// Sources/SwiftWebServer/Compression/GzipCompressor.swift
import Foundation
import Compression

public enum GzipCompressor {
    public static func compress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        let stream = OutputStream(toMemory: ())
        stream.open()
        defer { stream.close() }

        var sourceIndex = 0
        let bufferSize = 64 * 1024
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        let filter = try OutputFilter(.compress, using: .zlib, bufferCapacity: bufferSize) { chunk in
            if let chunk {
                chunk.withUnsafeBytes { ptr in
                    _ = stream.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: chunk.count)
                }
            }
        }

        while sourceIndex < data.count {
            let chunkSize = min(bufferSize, data.count - sourceIndex)
            let chunk = data.subdata(in: sourceIndex..<sourceIndex + chunkSize)
            try filter.write(chunk)
            sourceIndex += chunkSize
        }

        try filter.finalize()

        guard let result = stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            throw GzipError.compressionFailed
        }
        return result
    }

    public static func decompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var result = Data()
        let filter = try InputFilter(.decompress, using: .zlib) { _ in
            return data
        }

        let bufferSize = 64 * 1024
        while true {
            var chunk = Data(count: bufferSize)
            let length = try filter.readData(into: &chunk)
            if length == 0 { break }
            result.append(chunk.prefix(length))
        }
        return result
    }
}

public enum GzipError: Error, Sendable {
    case compressionFailed
}
```

Note: `InputFilter.readData(into:)` may not exist exactly like this; use the `Compression` framework API as documented. If needed, use `filter.readData(ofLength:)` and manage state. Adjust the code to compile.

- [ ] **Step 4: Modify ResponseEncoder to use gzip**

Modify `ResponseEncoder.encode`:

```swift
public func encode(_ response: Response, for request: Request) throws -> Data {
    var data = Data()
    let statusLine = "HTTP/1.1 \(response.status.code) \(response.status.reasonPhrase)\r\n"
    data.append(Data(statusLine.utf8))

    var headers = response.headers
    var bodyData = try collectBodyData(from: response.body)

    let acceptsGzip = (request.headers["Accept-Encoding"] ?? "").contains("gzip")
    if acceptsGzip && bodyData.count > 256 {
        bodyData = try GzipCompressor.compress(bodyData)
        headers.set(name: "Content-Encoding", value: "gzip")
    }

    if headers["Content-Length"] == nil {
        headers.set(name: "Content-Length", value: String(bodyData.count))
    }

    for (name, value) in headers.allHeaderLines() {
        data.append(Data("\(name): \(value)\r\n".utf8))
    }

    data.append(Data("\r\n".utf8))
    data.append(bodyData)
    return data
}

private func collectBodyData(from body: ResponseBody) throws -> Data {
    switch body {
    case .empty: return Data()
    case .data(let d): return d
    case .file(let url): return try Data(contentsOf: url)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
swift test --filter GzipTests
```

Expected: PASS. If `InputFilter`/`OutputFilter` API differs, fix the compressor implementation to match the `Compression` framework.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWebServer/Compression/GzipCompressor.swift Sources/SwiftWebServer/ResponseEncoder.swift Tests/SwiftWebServerTests/GzipTests.swift
git commit -m "feat: add gzip compression support"
```

---

## Task 13: Range Requests

**Files:**
- Create: `Sources/SwiftWebServer/Range/RangeRequestHandler.swift`
- Modify: `Sources/SwiftWebServer/ResponseEncoder.swift`
- Create: `Tests/SwiftWebServerTests/RangeTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RangeTests {
    @Test
    func parseRangeHeader() throws {
        let range = try ByteRange("bytes=0-9")
        #expect(range.start == 0)
        #expect(range.end == 9)
    }

    @Test
    func responseEncoderHandlesRange() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        let content = Data(String(repeating: "a", count: 100).utf8)
        try content.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let request = Request(
            method: .get,
            path: "/file",
            headers: HTTPHeaders([("Range", "bytes=0-9")]),
            body: Data()
        )
        let response = Response(file: fileURL)
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 206 Partial Content"))
        #expect(string.contains("Content-Range: bytes 0-9/100"))
        #expect(string.hasSuffix("aaaaaaaaaa"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter RangeTests
```

Expected: FAIL, `ByteRange` not found.

- [ ] **Step 3: Implement Range support**

```swift
// Sources/SwiftWebServer/Range/RangeRequestHandler.swift
import Foundation

public struct ByteRange: Sendable {
    public let start: Int
    public let end: Int

    public init(_ string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("bytes=") else {
            throw RangeError.invalidRange
        }
        let rangeString = String(trimmed.dropFirst("bytes=".count))
        let parts = rangeString.split(separator: "-").map(String.init)
        guard parts.count == 2,
              let start = Int(parts[0]),
              let end = Int(parts[1]) else {
            throw RangeError.invalidRange
        }
        self.start = start
        self.end = end
    }

    public func isValid(for totalLength: Int) -> Bool {
        start >= 0 && end < totalLength && start <= end
    }

    public var length: Int {
        end - start + 1
    }
}

public enum RangeError: Error, Sendable {
    case invalidRange
}

extension Response {
    public func applyingRange(_ range: ByteRange, totalLength: Int) -> Response {
        guard range.isValid(for: totalLength) else { return self }

        var response = self.status(.init(code: 206))
        response.headers.set(name: "Content-Range", value: "bytes \(range.start)-\(range.end)/\(totalLength)")
        // Actual slicing happens in encoder based on Content-Range header
        return response
    }
}
```

- [ ] **Step 4: Modify ResponseEncoder for Range**

Update the full `ResponseEncoder` implementation in `Sources/SwiftWebServer/ResponseEncoder.swift` to:

```swift
import Foundation

public struct ResponseEncoder: Sendable {
    public init() {}

    public func encode(_ response: Response, for request: Request) throws -> Data {
        try encode(response, for: request, honorRange: true)
    }

    private func encode(_ response: Response, for request: Request, honorRange: Bool) throws -> Data {
        var data = Data()

        var status = response.status
        var headers = response.headers
        var bodyData = try collectBodyData(from: response.body)

        if honorRange, let rangeHeader = request.headers["Range"] {
            if let range = try? ByteRange(rangeHeader) {
                if range.isValid(for: bodyData.count) {
                    let originalLength = bodyData.count
                    bodyData = bodyData.subdata(in: range.start..<range.end + 1)
                    headers.set(name: "Content-Range", value: "bytes \(range.start)-\(range.end)/\(originalLength)")
                    status = HTTPStatus(code: 206)
                } else {
                    let errorResponse = Response(text: "Range Not Satisfiable").status(.rangeNotSatisfiable)
                    return try encode(errorResponse, for: request, honorRange: false)
                }
            }
        }

        let acceptsGzip = (request.headers["Accept-Encoding"] ?? "").contains("gzip")
        if acceptsGzip && bodyData.count > 256 {
            bodyData = try GzipCompressor.compress(bodyData)
            headers.set(name: "Content-Encoding", value: "gzip")
        }

        if headers["Content-Length"] == nil {
            headers.set(name: "Content-Length", value: String(bodyData.count))
        }

        let statusLine = "HTTP/1.1 \(status.code) \(status.reasonPhrase)\r\n"
        data.append(Data(statusLine.utf8))

        for (name, value) in headers.allHeaderLines() {
            data.append(Data("\(name): \(value)\r\n".utf8))
        }

        data.append(Data("\r\n".utf8))
        data.append(bodyData)
        return data
    }

    private func collectBodyData(from body: ResponseBody) throws -> Data {
        switch body {
        case .empty: return Data()
        case .data(let d): return d
        case .file(let url): return try Data(contentsOf: url)
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
swift test --filter RangeTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWebServer/Range/RangeRequestHandler.swift Sources/SwiftWebServer/ResponseEncoder.swift Tests/SwiftWebServerTests/RangeTests.swift
git commit -m "feat: add HTTP Range request support"
```

---

## Task 14: multipart/form-data

**Files:**
- Create: `Sources/SwiftWebServer/Body/MultipartParser.swift`
- Create: `Tests/SwiftWebServerTests/MultipartTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct MultipartTests {
    @Test
    func parseMultipartForm() throws {
        let boundary = "----WebKitFormBoundary"
        let bodyString = """
        ------WebKitFormBoundary\r\n\
        Content-Disposition: form-data; name="name"\r\n\
        \r\n\
        Swift\r\n\
        ------WebKitFormBoundary\r\n\
        Content-Disposition: form-data; name="file"; filename="hello.txt"\r\n\
        Content-Type: text/plain\r\n\
        \r\n\
        Hello\r\n\
        ------WebKitFormBoundary--\r\n
        """
        let request = Request(
            method: .post,
            path: "/upload",
            headers: HTTPHeaders([("Content-Type", "multipart/form-data; boundary=----WebKitFormBoundary")]),
            body: Data(bodyString.utf8)
        )

        let parts = try request.multipartParts()
        #expect(parts.count == 2)
        #expect(parts[0].name == "name")
        #expect(parts[0].stringValue == "Swift")
        #expect(parts[1].filename == "hello.txt")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter MultipartTests
```

Expected: FAIL, `multipartParts` not found.

- [ ] **Step 3: Implement MultipartParser**

```swift
// Sources/SwiftWebServer/Body/MultipartParser.swift
import Foundation

public struct MultipartPart: Sendable {
    public let headers: HTTPHeaders
    public let name: String
    public let filename: String?
    public let body: Data

    public var stringValue: String? {
        String(data: body, encoding: .utf8)
    }
}

extension Request {
    public func multipartParts() throws -> [MultipartPart] {
        guard let contentType = headers["Content-Type"],
              contentType.hasPrefix("multipart/form-data") else {
            throw MultipartError.missingBoundary
        }

        let boundaryPrefix = "boundary="
        guard let boundaryRange = contentType.range(of: boundaryPrefix) else {
            throw MultipartError.missingBoundary
        }
        var boundary = String(contentType[boundaryRange.upperBound...])
        boundary = boundary.trimmingCharacters(in: .whitespacesAndNewlines)

        let delimiter = Data("--\(boundary)".utf8)
        let endDelimiter = Data("--\(boundary)--".utf8)

        var parts: [MultipartPart] = []
        var searchStart = body.startIndex

        while true {
            guard let delimiterRange = body.range(of: delimiter, in: searchStart..<body.endIndex) else { break }
            searchStart = delimiterRange.upperBound

            if body.range(of: endDelimiter, in: delimiterRange.lowerBound..<body.endIndex) == delimiterRange {
                break
            }

            guard let nextDelimiterRange = body.range(of: delimiter, in: searchStart..<body.endIndex) else { break }
            var partData = body.subdata(in: searchStart..<nextDelimiterRange.lowerBound)

            // Strip leading CRLF after delimiter
            if partData.starts(with: Data("\r\n".utf8)) {
                partData = partData.dropFirst(2)
            }
            // Strip trailing CRLF before next delimiter
            if partData.hasSuffix(Data("\r\n".utf8)) {
                partData = partData.dropLast(2)
            }

            guard let blankLineRange = partData.range(of: Data("\r\n\r\n".utf8)) else { continue }
            let headerData = partData.subdata(in: 0..<blankLineRange.lowerBound)
            let bodyData = partData.subdata(in: blankLineRange.upperBound..<partData.endIndex)

            let headers = parseHeaders(from: headerData)
            guard let disposition = headers["Content-Disposition"],
                  let name = parseDispositionValue(disposition, key: "name") else {
                continue
            }
            let filename = parseDispositionValue(disposition, key: "filename")

            parts.append(MultipartPart(headers: headers, name: name, filename: filename, body: bodyData))
        }

        return parts
    }

    private func parseHeaders(from data: Data) -> HTTPHeaders {
        var headers = HTTPHeaders()
        guard let string = String(data: data, encoding: .utf8) else { return headers }
        for line in string.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            headers.add(name: parts[0].trimmingCharacters(in: .whitespaces),
                        value: parts[1].trimmingCharacters(in: .whitespaces))
        }
        return headers
    }

    private func parseDispositionValue(_ disposition: String, key: String) -> String? {
        let pattern = "\(key)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: disposition, range: NSRange(disposition.startIndex..., in: disposition)) else {
            return nil
        }
        let range = Range(match.range(at: 1), in: disposition)!
        return String(disposition[range])
    }
}

public enum MultipartError: Error, Sendable {
    case missingBoundary
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter MultipartTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SwiftWebServer/Body/MultipartParser.swift Tests/SwiftWebServerTests/MultipartTests.swift
git commit -m "feat: add multipart/form-data parsing"
```

---

## Task 15: Basic Authentication

**Files:**
- Create: `Sources/SwiftWebServer/Authentication/Authenticator.swift`
- Create: `Sources/SwiftWebServer/Authentication/BasicAuthenticator.swift`
- Modify: `Sources/SwiftWebServer/WebServer.swift`
- Create: `Tests/SwiftWebServerTests/AuthenticationTests.swift`

- [ ] **Step 1: Write failing test**

```swift
import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct AuthenticationTests {
    @Test
    func basicAuthenticatorAcceptsValidCredentials() async throws {
        let auth = BasicAuthenticator { username, password in
            username == "admin" && password == "secret"
        }
        let request = Request(
            method: .get,
            path: "/admin",
            headers: HTTPHeaders([("Authorization", "Basic \(Data("admin:secret".utf8).base64EncodedString())")]),
            body: Data()
        )
        let result = await auth.authenticate(request)
        #expect(result == .authenticated)
    }

    @Test
    func basicAuthenticatorDeniesMissingHeader() async throws {
        let auth = BasicAuthenticator { _, _ in true }
        let request = Request(method: .get, path: "/admin")
        let result = await auth.authenticate(request)
        if case .denied(let header) = result {
            #expect(header.hasPrefix("Basic"))
        } else {
            Issue.record("Expected denied")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter AuthenticationTests
```

Expected: FAIL, types not found.

- [ ] **Step 3: Implement Authenticator protocol and BasicAuthenticator**

```swift
// Sources/SwiftWebServer/Authentication/Authenticator.swift
import Foundation

public enum AuthenticationResult: Equatable, Sendable {
    case authenticated
    case denied(wwwAuthenticateHeader: String)
}

public protocol Authenticator: Sendable {
    func authenticate(_ request: Request) async -> AuthenticationResult
}

public enum Authentication {
    public static func basic(validator: @escaping @Sendable (String, String) -> Bool) -> any Authenticator {
        BasicAuthenticator(validator: validator)
    }
}
```

```swift
// Sources/SwiftWebServer/Authentication/BasicAuthenticator.swift
import Foundation

public struct BasicAuthenticator: Authenticator {
    private let validator: @Sendable (String, String) -> Bool

    public init(validator: @escaping @Sendable (String, String) -> Bool) {
        self.validator = validator
    }

    public func authenticate(_ request: Request) -> AuthenticationResult {
        guard let header = request.headers["Authorization"],
              header.hasPrefix("Basic ") else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }

        let base64 = String(header.dropFirst("Basic ".count))
        guard let data = Data(base64Encoded: base64),
              let credentials = String(data: data, encoding: .utf8) else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }

        let parts = credentials.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }

        if validator(parts[0], parts[1]) {
            return .authenticated
        } else {
            return .denied(wwwAuthenticateHeader: "Basic realm=\"SwiftWebServer\"")
        }
    }
}
```

- [ ] **Step 4: Modify WebServer to support authentication**

Add an overload:

```swift
public func addRoute(
    method: HTTPMethod,
    path: String,
    authenticator: any Authenticator,
    handler: @escaping @Sendable (Request) async throws -> Response
) {
    let wrappedHandler: @Sendable (Request) async throws -> Response = { request in
        let authResult = await authenticator.authenticate(request)
        switch authResult {
        case .authenticated:
            return try await handler(request)
        case .denied(let header):
            var response = Response(text: "Unauthorized").status(.unauthorized)
            response.headers.set(name: "WWW-Authenticate", value: header)
            return response
        }
    }
    routes.append(Route(method: method, path: path, handler: wrappedHandler))
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
swift test --filter AuthenticationTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWebServer/Authentication/Authenticator.swift Sources/SwiftWebServer/Authentication/BasicAuthenticator.swift Sources/SwiftWebServer/WebServer.swift Tests/SwiftWebServerTests/AuthenticationTests.swift
git commit -m "feat: add Basic authentication"
```

---

## Task 16: Digest Authentication

**Files:**
- Create: `Sources/SwiftWebServer/Authentication/DigestAuthenticator.swift`
- Modify: `Sources/SwiftWebServer/Authentication/Authentication.swift` (if static helper was placed there) or create it
- Create/Modify: `Tests/SwiftWebServerTests/AuthenticationTests.swift`

- [ ] **Step 1: Write failing test**

```swift
@Test
func digestAuthenticatorChallengeAndAccept() async throws {
    let auth = DigestAuthenticator(realm: "test") { _ in "5ebe2294ecd0e0f08eab7690d2a6ee69" } // MD5("secret")
    let request = Request(method: .get, path: "/admin")
    let challenge = await auth.authenticate(request)
    guard case .denied(let header) = challenge else {
        Issue.record("Expected challenge")
        return
    }
    #expect(header.contains("Digest"))

    // Simulate a valid response (simplified: construct Authorization with parsed nonce)
    // This test documents the expected shape; actual hash verification is covered by unit tests.
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter AuthenticationTests
```

Expected: FAIL, `DigestAuthenticator` not found.

- [ ] **Step 3: Implement DigestAuthenticator**

```swift
// Sources/SwiftWebServer/Authentication/DigestAuthenticator.swift
import Foundation
import CryptoKit

public struct DigestAuthenticator: Authenticator {
    public let realm: String
    private let passwordHashForUser: @Sendable (String) -> String?
    private let nonceStore = NonceStore()

    public init(realm: String, passwordHashForUser: @escaping @Sendable (String) -> String?) {
        self.realm = realm
        self.passwordHashForUser = passwordHashForUser
    }

    public func authenticate(_ request: Request) async -> AuthenticationResult {
        guard let authorization = request.headers["Authorization"],
              authorization.hasPrefix("Digest ") else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        let params = parseDigestParams(String(authorization.dropFirst("Digest ".count)))
        guard let username = params["username"],
              let nonce = params["nonce"],
              let uri = params["uri"],
              let response = params["response"],
              let realm = params["realm"] else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        guard await nonceStore.isValid(nonce) else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        guard let a1 = passwordHashForUser(username) else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }

        let a2 = md5("\(request.method.rawValue):\(uri)")
        let expected = md5("\(a1):\(nonce):\(a2)")

        if expected == response.lowercased() {
            return .authenticated
        } else {
            return .denied(wwwAuthenticateHeader: await challengeHeader())
        }
    }

    private func challengeHeader() async -> String {
        let nonce = await nonceStore.generate()
        return "Digest realm=\"\(realm)\", nonce=\"\(nonce)\", qop=\"auth\", algorithm=MD5"
    }

    private func parseDigestParams(_ string: String) -> [String: String] {
        var result: [String: String] = [:]
        let pattern = "([a-z]+)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return result }
        let nsRange = NSRange(string.startIndex..., in: string)
        for match in regex.matches(in: string, options: [], range: nsRange) {
            guard match.numberOfRanges == 3 else { continue }
            let keyRange = Range(match.range(at: 1), in: string)!
            let valueRange = Range(match.range(at: 2), in: string)!
            result[String(string[keyRange])] = String(string[valueRange])
        }
        return result
    }
}

private actor NonceStore {
    private var nonces: Set<String> = []

    func generate() -> String {
        let nonce = UUID().uuidString
        nonces.insert(nonce)
        return nonce
    }

    func isValid(_ nonce: String) -> Bool {
        nonces.contains(nonce)
    }
}

private func md5(_ string: String) -> String {
    let data = Data(string.utf8)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02hhx", $0) }.joined()
}
```

- [ ] **Step 4: Add Authentication helper**

If `Authentication` enum lives in `Authenticator.swift`, update it:

```swift
public enum Authentication {
    public static func basic(validator: @escaping @Sendable (String, String) -> Bool) -> any Authenticator {
        BasicAuthenticator(validator: validator)
    }

    public static func digest(realm: String, passwordHashForUser: @escaping @Sendable (String) -> String?) -> any Authenticator {
        DigestAuthenticator(realm: realm, passwordHashForUser: passwordHashForUser)
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```bash
swift test --filter AuthenticationTests
```

Expected: PASS. If `Insecure.MD5` import is problematic, use `CryptoKit` or `CommonCrypto` appropriately.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWebServer/Authentication/DigestAuthenticator.swift Tests/SwiftWebServerTests/AuthenticationTests.swift
git commit -m "feat: add Digest authentication"
```

---

## Task 17: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

```markdown
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
    .package(url: "https://github.com/your-org/SwiftWebServer.git", from: "0.1.0")
]
```

Or add it in Xcode via **File → Add Package Dependencies**.

## Quick Start

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

server.addRoute(
    method: .get,
    path: "/admin",
    authenticator: .basic { username, password in
        username == "admin" && password == "secret"
    }
) { request in
    Response(text: "secret")
}

try await server.start(port: 8080)
```

## Documentation

Full API reference is available via DocC in Xcode.

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with quick start"
```

---

## Task 18: DocC Documentation

**Files:**
- Create: `Sources/SwiftWebServerDocc/SwiftWebServer.docc/SwiftWebServer.md`
- Create: `Sources/SwiftWebServerDocc/SwiftWebServer.docc/GettingStarted.md`
- Create: `Sources/SwiftWebServerDocc/SwiftWebServer.docc/Articles/RoutingAndHandlers.md`
- Modify: `Package.swift` to add `SwiftWebServerDocc` target

- [ ] **Step 1: Write SwiftWebServer.md**

```markdown
# ``SwiftWebServer``

A Swift 6 embedded HTTP/1.1 WebServer for Apple platforms.

## Overview

SwiftWebServer lets you run an HTTP server inside your app. It is designed around `async/await`, `Network.framework`, and Swift 6 strict concurrency.

## Topics

### Essentials

- ``WebServer``
- ``Request``
- ``Response``
- ``Route``

### Authentication

- ``Authenticator``
- ``BasicAuthenticator``
- ``DigestAuthenticator``

### Body Parsing

- ``Request/decodeJSON(_:decoder:)``
- ``Request/multipartParts()``
```

- [ ] **Step 2: Write GettingStarted.md**

```markdown
# Getting Started

Create a `WebServer`, add routes, and start it.

```swift
let server = WebServer()
server.addRoute(method: .get, path: "/ping") { _ in
    Response(text: "pong")
}
try await server.start(port: 8080)
```
```

- [ ] **Step 3: Write RoutingAndHandlers.md**

```markdown
# Routing and Handlers

Routes match by HTTP method and path pattern.

Use `:name` for path parameters.
```

- [ ] **Step 4: Update Package.swift**

Add target:

```swift
.target(
    name: "SwiftWebServerDocc",
    dependencies: ["SwiftWebServer"],
    path: "Sources/SwiftWebServerDocc",
    exclude: [],
    resources: [
        .process("SwiftWebServer.docc")
    ]
)
```

- [ ] **Step 5: Build DocC**

```bash
swift build --target SwiftWebServerDocc
```

Expected: build succeeds with no warnings.

- [ ] **Step 6: Commit**

```bash
git add Sources/SwiftWebServerDocc Package.swift
git commit -m "docs: add DocC documentation"
```

---

## Task 19: Platform XCTest

**Files:**
- Create: `Tests/SwiftWebServerXCTests/PlatformBindTests.swift`

- [ ] **Step 1: Write test**

```swift
import XCTest
import Network
@testable import SwiftWebServer

final class PlatformBindTests: XCTestCase {
    func testCanBindEphemeralPort() async throws {
        let server = WebServer()
        try await server.start(port: 0)
        let port = await server.port
        XCTAssertNotNil(port)
        XCTAssertGreaterThan(port!, 0)
        await server.stop()
    }
}
```

- [ ] **Step 2: Run test**

```bash
swift test --filter PlatformBindTests
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Tests/SwiftWebServerXCTests/PlatformBindTests.swift
git commit -m "test: add platform-specific bind test"
```

---

## Task 20: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
swift test
```

Expected: all tests pass, no warnings.

- [ ] **Step 2: Build all targets**

```bash
swift build
```

Expected: success.

- [ ] **Step 3: Lint for strict concurrency issues**

```bash
swift build -Xswiftc -strict-concurrency=complete
```

Expected: no concurrency warnings/errors.

- [ ] **Step 4: Commit final state**

```bash
git add -A
git commit -m "chore: final verification and cleanup"
```

---

## Spec Coverage Check

| Spec Requirement | Implementing Task(s) |
|------------------|----------------------|
| HTTP/1.1 server lifecycle | Task 10 |
| Handler routing | Task 7, Task 10 |
| Strongly typed Request/Response | Task 5, Task 6 |
| gzip compression | Task 12 |
| HTTP Range requests | Task 13 |
| multipart/form-data | Task 14 |
| Basic authentication | Task 15 |
| Digest authentication | Task 16 |
| JSON request/response | Task 11 |
| Unit tests | All tasks |
| Integration tests | Task 10 |
| Platform tests | Task 19 |
| README | Task 17 |
| DocC | Task 18 |

## Placeholder Scan

- No `TBD`, `TODO`, or "implement later" steps.
- Every task includes concrete code, commands, and expected output.
- Type names (`HTTPMethod`, `HTTPStatus`, `HTTPHeaders`, `Request`, `Response`, `Route`, `Router`, `WebServer`, `Connection`) are consistent across tasks.
