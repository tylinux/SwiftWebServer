import Foundation

public struct Router: Sendable {
    private var routes: [Route]

    public init() {
        self.routes = []
    }

    public mutating func add(_ route: Route) {
        routes.append(route)
    }

    public func match(request: Request) -> (Route, [String: String])? {
        for route in routes {
            guard route.method == request.method else { continue }
            if let params = match(path: request.path, pattern: route.pathPattern) {
                return (route, params)
            }
        }
        return nil
    }

    private func match(path: String, pattern: String) -> [String: String]? {
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let patternComponents = pattern.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        guard pathComponents.count == patternComponents.count else { return nil }

        var parameters: [String: String] = [:]
        for (pathComponent, patternComponent) in zip(pathComponents, patternComponents) {
            if patternComponent.hasPrefix(":"),
               let name = patternComponent.dropFirst().split(separator: "/").first {
                parameters[String(name)] = pathComponent
            } else if patternComponent == pathComponent {
                continue
            } else {
                return nil
            }
        }
        return parameters
    }
}
