import Foundation
import Network
import Testing
@testable import SwiftWebServer

@Suite(.serialized)
struct KeepAliveTests {
    private func rawResponses(host: String, port: UInt16, request: Data) async throws -> Data {
        let endpoint = NWEndpoint.hostPort(host: .name(host, nil), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
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
            connection.send(content: request, completion: .contentProcessed({ error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }))
        }

        var allData = Data()
        var isComplete = false
        while !isComplete {
            do {
                let chunk = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data?, Bool), Error>) in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, complete, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: (data, complete))
                        }
                    }
                }
                if let data = chunk.0 {
                    allData.append(data)
                }
                isComplete = chunk.1
            } catch {
                isComplete = true
            }
        }
        connection.cancel()
        return allData
    }

    private func statusCodes(in data: Data) -> [Int] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let prefix = "HTTP/1.1 "
        var codes: [Int] = []
        var searchStart = text.startIndex
        while let range = text[searchStart...].range(of: prefix) {
            let codeStart = range.upperBound
            let codeSubstring = text[codeStart...].prefix(3)
            if let code = Int(codeSubstring) {
                codes.append(code)
            }
            searchStart = range.upperBound
        }
        return codes
    }

    @Test
    func handlesTwoRequestsOnOneConnection() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/hello") { _ in
            Response(text: "hi")
        }
        try await server.start(port: 0)
        let port = try #require(await server.port)

        let request = Data("GET /hello HTTP/1.1\r\nHost: localhost\r\n\r\nGET /hello HTTP/1.1\r\nConnection: close\r\n\r\n".utf8)
        let responses = try await rawResponses(host: "127.0.0.1", port: port, request: request)
        let codes = statusCodes(in: responses)

        #expect(codes == [200, 200])

        await server.stop()
    }

    @Test
    func includesConnectionKeepAliveHeaderByDefault() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/hello") { _ in
            Response(text: "hi")
        }
        try await server.start(port: 0)
        let port = try #require(await server.port)

        let request = Data("GET /hello HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".utf8)
        let responses = try await rawResponses(host: "127.0.0.1", port: port, request: request)
        let text = String(data: responses, encoding: .utf8) ?? ""

        #expect(text.contains("Connection: close"))

        await server.stop()
    }
}
