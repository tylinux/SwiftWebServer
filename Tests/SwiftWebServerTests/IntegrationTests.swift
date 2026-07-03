import Testing
import Foundation
@testable import SwiftWebServer

@Suite(.serialized)
struct IntegrationTests {
    @Test
    func getHello() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/hello") { _ in
            Response(text: "Hello, world!")
        }
        try await server.start(port: 0)
        let port = await server.port!

        let url = URL(string: "http://127.0.0.1:\(port)/hello")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "Hello, world!")

        await server.stop()
    }
}
