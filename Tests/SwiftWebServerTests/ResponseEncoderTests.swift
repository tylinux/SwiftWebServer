import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct ResponseEncoderTests {
    @Test
    func encodesTextResponse() throws {
        let request = Request(method: .get, path: "/")
        let response = Response(text: "hello")
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 200 OK"))
        #expect(string.contains("Content-Type: text/plain; charset=utf-8"))
        #expect(string.contains("Content-Length: 5"))
        #expect(string.hasSuffix("\r\n\r\nhello"))
    }
}
