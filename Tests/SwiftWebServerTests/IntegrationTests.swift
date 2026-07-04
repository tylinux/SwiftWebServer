import Testing
import Foundation
import Network
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
    func badRequest() async throws {
        let server = WebServer()
        try await server.start(port: 0)
        let port = try #require(await server.port)

        let request = Data("GET /\r\n\r\n".utf8)
        let statusCode = try await rawStatusCode(host: "127.0.0.1", port: port, request: request)
        #expect(statusCode == 400)

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

    @Test
    func chunkedResponse() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/stream") { _ in
            let stream = AsyncThrowingStream<Data, Error> { continuation in
                continuation.yield(Data("abc".utf8))
                continuation.yield(Data("def".utf8))
                continuation.finish()
            }
            var headers = HTTPHeaders()
            headers.set(name: "Content-Type", value: "text/plain")
            return Response(stream: stream, headers: headers)
        }
        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/stream")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "abcdef")

        await server.stop()
    }
}

enum TestError: Error, Sendable {
    case boom
}

private func rawStatusCode(host: String, port: UInt16, request: Data) async throws -> Int {
    let endpoint = NWEndpoint.hostPort(host: .name(host, nil), port: NWEndpoint.Port(rawValue: port)!)
    let connection = NWConnection(to: endpoint, using: .tcp)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        connection.stateUpdateHandler = { (state: NWConnection.State) in
            switch state {
            case .ready:
                connection.stateUpdateHandler = nil
                continuation.resume()
            case .failed(let error):
                connection.stateUpdateHandler = nil
                continuation.resume(throwing: error)
            case .cancelled:
                connection.stateUpdateHandler = nil
                continuation.resume(throwing: CancellationError())
            default:
                break
            }
        }
        connection.start(queue: .global())
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        connection.send(content: request, completion: NWConnection.SendCompletion.contentProcessed({ error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume()
            }
        }))
    }

    let responseData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?) in
            _ = context
            _ = isComplete
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: data ?? Data())
            }
        }
    }

    connection.cancel()

    guard let line = String(data: responseData, encoding: .utf8)?.split(separator: "\r\n").first else {
        return 0
    }
    let tokens = line.split(separator: " ")
    guard tokens.count >= 2, let code = Int(tokens[1]) else {
        return 0
    }
    return code
}
