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
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/hello")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "Hello, world!")

        await server.stop()
    }

    @Test
    func notFound() async throws {
        let server = WebServer()
        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/missing")!
        let (_, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 404)

        await server.stop()
    }

    @Test
    func serverError() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/fail") { _ in
            throw TestError.boom
        }
        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/fail")!
        let (_, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 500)

        await server.stop()
    }

    @Test
    func startAndStop() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/ping") { _ in
            Response(text: "pong")
        }
        #expect(await server.isRunning == false)
        try await server.start(port: 0)
        #expect(await server.isRunning == true)
        await server.stop()
        #expect(await server.isRunning == false)
    }
}

enum TestError: Error, Sendable {
    case boom
}
