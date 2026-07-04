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

        var parameters: [String: String] = [:]
        var pathIndex = 0

        for (patternIndex, patternComponent) in patternComponents.enumerated() {
            if patternComponent.hasSuffix("..."), patternComponent.hasPrefix(":") {
                guard patternIndex == patternComponents.count - 1 else { return nil }
                let nameStart = patternComponent.index(after: patternComponent.startIndex)
                let nameEnd = patternComponent.index(patternComponent.endIndex, offsetBy: -3)
                let name = String(patternComponent[nameStart..<nameEnd])
                let remaining = pathComponents[pathIndex...].joined(separator: "/")
                parameters[name] = remaining
                return parameters
            }

            guard pathIndex < pathComponents.count else { return nil }
            let pathComponent = pathComponents[pathIndex]

            if patternComponent.hasPrefix(":"),
               let name = patternComponent.dropFirst().split(separator: "/").first {
                parameters[String(name)] = pathComponent
            } else if patternComponent == pathComponent {
                // exact match
            } else {
                return nil
            }
            pathIndex += 1
        }

        guard pathIndex == pathComponents.count else { return nil }
        return parameters
    }
}
