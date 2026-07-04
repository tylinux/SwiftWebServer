import Foundation
import Network
import Security
import Testing
@testable import SwiftWebServer

@Suite(.serialized)
struct TLSTests {
    private func tlsResponse(
        host: String,
        port: UInt16,
        alpn: [String] = ["http/1.1"],
        request: Data
    ) async throws -> Data {
        let options = NWProtocolTLS.Options()
        let secOptions = options.securityProtocolOptions
        sec_protocol_options_set_peer_authentication_required(secOptions, false)
        for proto in alpn {
            sec_protocol_options_add_tls_application_protocol(secOptions, proto)
        }
        let params = NWParameters(tls: options)
        let endpoint = NWEndpoint.hostPort(host: .name(host, nil), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: params)

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
            connection.send(content: request, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }

        var allData = Data()
        var isComplete = false
        while !isComplete {
            do {
                let (data, complete) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Data?, Bool), Error>) in
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, complete, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: (data, complete))
                        }
                    }
                }
                if let data {
                    allData.append(data)
                }
                isComplete = complete
            } catch {
                isComplete = true
            }
        }
        connection.cancel()
        return allData
    }

    @Test
    func httpsRespondsToRequest() async throws {
        let identity = try TLSIdentity.makeSelfSigned()
        let server = WebServer()
        await server.addRoute(method: .get, path: "/") { _ in
            Response(text: "secure")
        }
        try await server.start(port: 0, tls: TLSConfiguration(identity: identity))
        let port = try #require(await server.port)

        let data = try await tlsResponse(
            host: "localhost",
            port: port,
            request: Data("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".utf8)
        )
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("HTTP/1.1 200 OK"))
        #expect(text.contains("secure"))

        await server.stop()
    }

    @Test
    func http2ALPNIsRejected() async throws {
        let identity = try TLSIdentity.makeSelfSigned()
        let server = WebServer()
        await server.addRoute(method: .get, path: "/") { _ in
            Response(text: "secure")
        }
        try await server.start(port: 0, tls: TLSConfiguration(identity: identity, applicationProtocols: ["h2", "http/1.1"]))
        let port = try #require(await server.port)

        let data = try await tlsResponse(host: "localhost", port: port, alpn: ["h2"], request: Data())
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("HTTP/1.1 505"))

        await server.stop()
    }
}
