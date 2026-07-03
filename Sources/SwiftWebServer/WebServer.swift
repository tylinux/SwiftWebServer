import Foundation
import Network

public actor WebServer {
    private var routes: [Route]
    private var listener: NWListener?
    private var stopContinuation: CheckedContinuation<Void, Never>?

    public init() {
        self.routes = []
    }

    public var isRunning: Bool {
        listener != nil
    }

    public var port: UInt16? {
        listener?.port?.rawValue
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
        let nwPort: NWEndpoint.Port = port == 0 ? .any : NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener

        let routesSnapshot = self.routes
        listener.newConnectionHandler = { connection in
            Task {
                let connectionActor = Connection(
                    connection: connection,
                    router: Router(routesSnapshot)
                )
                await connectionActor.start()
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                    Task { await self?.clearListener() }
                case .cancelled:
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }
    }

    private func clearListener() {
        listener = nil
    }

    public func stop() async {
        guard let listener else { return }
        self.listener = nil

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            listener.stateUpdateHandler = { state in
                if state == .cancelled {
                    continuation.resume()
                }
            }
            listener.cancel()
        }
    }
}
