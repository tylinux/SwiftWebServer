import Foundation
import Network

public enum WebServerError: Error, Sendable {
    case alreadyRunning
}

public actor WebServer {
    private var routes: [Route]
    private var listener: NWListener?
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var stopContinuation: CheckedContinuation<Void, Never>?

    /// Optional log handler. Set to `nil` to disable logging.
    public var logHandler: LogHandler?

    public func setLogHandler(_ handler: LogHandler?) {
        self.logHandler = handler
    }

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

    public func addStaticFiles(
        at pathPrefix: String,
        directory: URL,
        indexFile: String? = "index.html"
    ) {
        let trimmedPrefix = pathPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let pattern = "/" + trimmedPrefix + "/:path..."
        let handler = StaticFileHandler(rootDirectory: directory, indexFile: indexFile)
        addRoute(method: .get, path: pattern) { request in
            handler.response(for: request)
        }
        addRoute(method: .head, path: pattern) { request in
            handler.response(for: request)
        }
    }

    public func start(port: UInt16) async throws {
        guard listener == nil else {
            throw WebServerError.alreadyRunning
        }

        let parameters = NWParameters.tcp
        let nwPort: NWEndpoint.Port = port == 0 ? .any : NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener

        let routesSnapshot = self.routes
        let logger = self.logHandler
        listener.newConnectionHandler = { connection in
            Task {
                let connectionActor = Connection(
                    connection: connection,
                    router: Router(routesSnapshot),
                    logger: logger
                )
                await connectionActor.start()
            }
        }

        listener.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleListenerState(state)
            }
        }
        listener.start(queue: .global())

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.startContinuation = continuation
            }
            if let port = self.port {
                self.logHandler?(.info, "Server started on port \(port)")
            }
        } catch {
            self.listener = nil
            throw error
        }
    }

    public func stop() async {
        guard let listener else { return }
        self.listener = nil

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.stopContinuation = continuation
            listener.cancel()
        }
        self.logHandler?(.info, "Server stopped")
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            if let continuation = startContinuation {
                startContinuation = nil
                continuation.resume()
            }
        case .failed(let error):
            self.logHandler?(.error, "Listener failed: \(error)")
            if let continuation = startContinuation {
                startContinuation = nil
                continuation.resume(throwing: error)
            } else if let continuation = stopContinuation {
                stopContinuation = nil
                continuation.resume()
            }
        case .cancelled:
            if let continuation = startContinuation {
                startContinuation = nil
                continuation.resume(throwing: CancellationError())
            }
            if let continuation = stopContinuation {
                stopContinuation = nil
                continuation.resume()
            }
        default:
            break
        }
    }
}
