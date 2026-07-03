import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct ResponseTests {
    @Test
    func textResponse() {
        let response = Response(text: "hello")
        #expect(response.status == .ok)
        #expect(response.headers["Content-Type"] == "text/plain; charset=utf-8")
        #expect(response.stringBody == "hello")
    }

    @Test
    func statusChaining() {
        let response = Response(text: "created").status(.created)
        #expect(response.status == .created)
    }
}
