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

    private func sendErrorResponse(_ status: HTTPStatus) async throws {
        let response = Response(text: status.reasonPhrase, status: status)
        let request = Request(method: .get, path: "/")
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
