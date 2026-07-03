import Testing
import Foundation
@testable import SwiftWebServer

struct User: Codable, Equatable, Sendable {
    let name: String
}

@Suite
struct JSONBodyTests {
    @Test
    func decodeJSONRequestBody() throws {
        let data = Data("{\"name\":\"swift\"}".utf8)
        let request = Request(method: .post, path: "/user", headers: HTTPHeaders([("Content-Type", "application/json")]), body: data)
        let user: User = try request.decodeJSON()
        #expect(user == User(name: "swift"))
    }

    @Test
    func encodeJSONResponse() throws {
        let response = try Response(json: ["id": 1])
        #expect(response.headers["Content-Type"] == "application/json")
        #expect(response.stringBody == "{\"id\":1}")
    }
}
