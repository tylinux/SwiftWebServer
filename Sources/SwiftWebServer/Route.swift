import Foundation

public struct Route: Sendable {
    public let method: HTTPMethod
    public let pathPattern: String
    public let handler: @Sendable (Request) async throws -> Response

    public init(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (Request) async throws -> Response
    ) {
        self.method = method
        self.pathPattern = path
        self.handler = handler
    }
}
