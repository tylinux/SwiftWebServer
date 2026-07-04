import Foundation
import Network

internal actor Connection {
    private let connection: NWConnection
    private let router: Router
    private let logger: LogHandler?
    private var parser = HTTPRequestParser()

    init(connection: NWConnection, router: Router, logger: LogHandler? = nil) {
        self.connection = connection
        self.router = router
        self.logger = logger
    }

    func start() async {
        await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled:
                    self.connection.stateUpdateHandler = nil
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
            logger?(.error, "Connection error: \(error)")
        }
        connection.cancel()
    }

    func stop() {
        connection.cancel()
    }

    private func handleRequests() async throws {
        while true {
            // Try to parse any buffered bytes before waiting for more data.
            let parseResult: ParseResult
            do {
                parseResult = try parser.parse(Data())
            } catch {
                logger?(.warning, "Bad request: \(error)")
                try await sendErrorResponse(.badRequest, for: Request(method: .get, path: "/"))
                break
            }

            let request: Request
            if case .request(let parsedRequest, _) = parseResult {
                request = parsedRequest
            } else {
                let chunk = try await receive()
                if chunk.isEmpty { break }

                let result: ParseResult
                do {
                    result = try parser.parse(chunk)
                } catch {
                    logger?(.warning, "Bad request: \(error)")
                    try await sendErrorResponse(.badRequest, for: Request(method: .get, path: "/"))
                    break
                }

                guard case .request(let parsedRequest, _) = result else {
                    continue
                }
                request = parsedRequest
            }

            guard let (route, params) = router.match(request: request) else {
                logger?(.warning, "\(request.method.rawValue) \(request.path) 404")
                try await sendErrorResponse(.notFound, for: request)
                break
            }

            var routedRequest = Request(
                method: request.method,
                path: request.path,
                query: request.query,
                headers: request.headers,
                body: request.body,
                pathParameters: params,
                httpVersion: request.httpVersion
            )

            do {
                let response = try await route.handler(routedRequest)
                let encoded = try ResponseEncoder().encodeResponse(response, for: routedRequest)
                switch encoded {
                case .complete(let data):
                    try await send(data)
                    logger?(.info, "\(routedRequest.method.rawValue) \(routedRequest.path) \(response.status.code)")
                case .chunked(let headers, let stream):
                    try await send(headers)
                    do {
                        for try await chunk in stream {
                            guard !chunk.isEmpty else { continue }
                            var chunkData = Data(String(chunk.count, radix: 16, uppercase: false).utf8)
                            chunkData.append(Data("\r\n".utf8))
                            chunkData.append(chunk)
                            chunkData.append(Data("\r\n".utf8))
                            try await send(chunkData)
                        }
                        try await send(Data("0\r\n\r\n".utf8))
                        logger?(.info, "\(routedRequest.method.rawValue) \(routedRequest.path) \(response.status.code)")
                    } catch {
                        // Stream failed after headers were sent; close the connection.
                        break
                    }
                }
            } catch {
                logger?(.error, "Handler error: \(error)")
                try await sendErrorResponse(.internalServerError, for: routedRequest)
                break
            }

            if shouldCloseConnection(after: routedRequest) {
                break
            }
        }
    }

    private func shouldCloseConnection(after request: Request) -> Bool {
        let connectionHeader = request.headers["Connection"]?.lowercased()
        if connectionHeader == "close" {
            return true
        }
        if request.httpVersion.hasPrefix("HTTP/1.0"), connectionHeader != "keep-alive" {
            return true
        }
        return false
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func sendErrorResponse(_ status: HTTPStatus, for request: Request) async throws {
        let response = Response(text: status.reasonPhrase, status: status)
        let encoded = try ResponseEncoder().encode(response, for: request)
        try await send(encoded)
    }
}

extension Router {
    init(_ routes: [Route]) {
        self.init()
        for route in routes {
            self.add(route)
        }
    }
}
