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
        let response = try Response(json: User(name: "swift"))
        #expect(response.headers["Content-Type"] == "application/json")
        let decoded: User = try response.dataBody!.decodeJSON()
        #expect(decoded == User(name: "swift"))
    }

    @Test
    func rejectsInvalidJSON() {
        let data = Data("not json".utf8)
        let request = Request(method: .post, path: "/user", body: data)
        #expect(throws: (any Error).self) {
            let _: User = try request.decodeJSON()
        }
    }
}

extension Data {
    fileprivate func decodeJSON<T: Decodable & Sendable>(_ type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(type, from: self)
    }
}
