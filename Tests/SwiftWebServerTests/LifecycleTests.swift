import Foundation
import Testing
@testable import SwiftWebServer

@Suite(.serialized)
struct LifecycleTests {
    @Test
    func suspendAndResume() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/") { _ in
            Response(text: "ok")
        }

        #expect(await server.isRunning == false)
        #expect(await server.isSuspended == false)

        try await server.start(port: 0)
        let firstPort = try #require(await server.port)
        #expect(await server.isRunning == true)

        await server.suspend()
        #expect(await server.isRunning == false)
        #expect(await server.isSuspended == true)

        try await server.resume()
        #expect(await server.isRunning == true)
        #expect(await server.isSuspended == false)

        let secondPort = try #require(await server.port)
        #expect(secondPort == firstPort)

        let url = URL(string: "http://127.0.0.1:\(secondPort)/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        #expect(String(data: data, encoding: .utf8) == "ok")

        await server.stop()
        #expect(await server.isRunning == false)
        #expect(await server.isSuspended == false)
    }

    @Test
    func stopClosesActiveConnections() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/") { _ in
            Response(text: "ok")
        }

        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        #expect(String(data: data, encoding: .utf8) == "ok")

        await server.stop()
        #expect(await server.isRunning == false)
    }
}
