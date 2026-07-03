import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RouterTests {
    @Test
    func exactMatch() async throws {
        var router = Router()
        router.add(Route(method: .get, path: "/hello") { _ in Response(text: "hi") })

        let request = Request(method: .get, path: "/hello")
        let (route, params) = try #require(router.match(request: request))
        let response = try await route.handler(request)
        #expect(response.stringBody == "hi")
        #expect(params.isEmpty)
    }

    @Test
    func pathParameterMatch() async throws {
        var router = Router()
        router.add(Route(method: .get, path: "/files/:name") { _ in Response(text: "ok") })

        let request = Request(method: .get, path: "/files/report.pdf")
        let (_, params) = try #require(router.match(request: request))
        #expect(params["name"] == "report.pdf")
    }

    @Test
    func methodMismatchReturnsNil() {
        var router = Router()
        router.add(Route(method: .post, path: "/hello") { _ in Response(text: "hi") })
        let request = Request(method: .get, path: "/hello")
        #expect(router.match(request: request) == nil)
    }
}
