import Foundation
import Testing
@testable import SwiftWebServer

private final class LogCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _messages: [(LogLevel, String)] = []

    var messages: [(LogLevel, String)] {
        lock.withLock { _messages }
    }

    func log(_ level: LogLevel, _ message: String) {
        lock.withLock { _messages.append((level, message)) }
    }

    var handler: LogHandler {
        { [weak self] level, message in
            self?.log(level, message)
        }
    }
}

struct LoggerTests {
    @Test
    func logsServerStartAndStop() async throws {
        let server = WebServer()
        let collector = LogCollector()
        await server.addRoute(method: .get, path: "/") { _ in
            Response(text: "ok")
        }
        await server.setLogHandler(collector.handler)

        try await server.start(port: 0)
        let port = try #require(await server.port)
        await server.stop()

        #expect(collector.messages.contains { $0.0 == .info && $0.1.contains("Server started on port \(port)") })
        #expect(collector.messages.contains { $0.0 == .info && $0.1 == "Server stopped" })
    }

    @Test
    func logsRequestAndResponse() async throws {
        let server = WebServer()
        let collector = LogCollector()
        await server.addRoute(method: .get, path: "/hello") { _ in
            Response(text: "ok")
        }
        await server.setLogHandler(collector.handler)

        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/hello")!
        _ = try await URLSession.shared.data(from: url)

        await server.stop()

        #expect(collector.messages.contains { $0.0 == .info && $0.1.contains("GET /hello 200") })
    }

    @Test
    func logsNotFound() async throws {
        let server = WebServer()
        let collector = LogCollector()
        await server.setLogHandler(collector.handler)

        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/missing")!
        _ = try await URLSession.shared.data(from: url)

        await server.stop()

        #expect(collector.messages.contains { $0.0 == .warning && $0.1.contains("GET /missing 404") })
    }
}
