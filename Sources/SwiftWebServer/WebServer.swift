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

    private var lastPort: UInt16?
    private var lastParameters: NWParameters?
    private var isSuspendedValue: Bool = false

    private var activeConnections: [UUID: Connection] = [:]
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    /// Optional log handler. Set to `nil` to disable logging.
    public var logHandler: LogHandler?

    public init() {
        self.routes = []
    }

    public var isRunning: Bool {
        listener != nil
    }

    public var isSuspended: Bool {
        isSuspendedValue
    }

    public var port: UInt16? {
        listener?.port?.rawValue
    }

    public func setLogHandler(_ handler: LogHandler?) {
        self.logHandler = handler
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
        try await start(port: port, parameters: NWParameters.tcp)
    }

    private func start(port: UInt16, parameters: NWParameters) async throws {
        guard listener == nil else {
            throw WebServerError.alreadyRunning
        }

        self.lastPort = port
        self.lastParameters = parameters

        let nwPort: NWEndpoint.Port = port == 0 ? .any : NWEndpoint.Port(rawValue: port)!
        let listener = try NWListener(using: parameters, on: nwPort)
        self.listener = listener

        let routesSnapshot = self.routes
        let logger = self.logHandler
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            let id = UUID()
            let connectionActor = Connection(
                connection: connection,
                router: Router(routesSnapshot),
                logger: logger
            )
            Task { [weak self] in
                await self?.runConnection(id: id, connection: connectionActor)
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
            self.lastPort = self.port ?? port
            self.lastParameters = parameters
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
        self.isSuspendedValue = false

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.stopContinuation = continuation
            listener.cancel()
        }

        await shutdownActiveConnections()
        self.logHandler?(.info, "Server stopped")
    }

    public func suspend() async {
        guard !isSuspendedValue, listener != nil else { return }
        guard let listener else { return }

        self.listener = nil
        self.isSuspendedValue = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.stopContinuation = continuation
            listener.cancel()
        }

        await shutdownActiveConnections()
        self.logHandler?(.info, "Server suspended")
    }

    public func resume() async throws {
        guard isSuspendedValue, listener == nil else { return }
        guard let lastPort else { return }

        try await start(port: lastPort, parameters: lastParameters ?? NWParameters.tcp)
        self.isSuspendedValue = false
        self.logHandler?(.info, "Server resumed")
    }

    private func runConnection(id: UUID, connection: Connection) async {
        activeConnections[id] = connection
        let task = Task {
            await connection.start()
        }
        activeTasks[id] = task
        await task.value
        activeConnections.removeValue(forKey: id)
        activeTasks.removeValue(forKey: id)
    }

    private func shutdownActiveConnections() async {
        for (_, connection) in activeConnections {
            await connection.stop()
        }
        for (_, task) in activeTasks {
            await task.value
        }
        activeConnections.removeAll()
        activeTasks.removeAll()
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
