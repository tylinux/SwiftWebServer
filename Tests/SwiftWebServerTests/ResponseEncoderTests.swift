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

    @Test
    func suppressesBodyForHead() throws {
        let request = Request(method: .head, path: "/")
        let response = Response(text: "hello")
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("Content-Length: 5"))
        #expect(!string.contains("\r\n\r\nhello"))
        #expect(string.hasSuffix("\r\n\r\n"))
    }

    @Test
    func encodesCustomStatusAndHeader() throws {
        let request = Request(method: .get, path: "/")
        var response = Response(text: "created").status(.created)
        response.headers.set(name: "X-Custom", value: "value")
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 201 Created"))
        #expect(string.contains("X-Custom: value"))
    }
}
