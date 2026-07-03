import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RequestTests {
    @Test
    func queryParameters() {
        let request = Request(
            method: .get,
            path: "/search",
            query: ["q": "swift", "page": "2"],
            headers: HTTPHeaders(),
            body: Data(),
            pathParameters: [:]
        )
        #expect(request.query["q"] == "swift")
        #expect(request.query["page"] == "2")
    }

    @Test
    func pathParameterLookup() {
        let request = Request(
            method: .get,
            path: "/files/report.pdf",
            query: [:],
            headers: HTTPHeaders(),
            body: Data(),
            pathParameters: ["name": "report.pdf"]
        )
        #expect(request.pathParameter("name") == "report.pdf")
    }
}
