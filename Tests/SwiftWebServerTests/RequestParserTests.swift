import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RequestParserTests {
    @Test
    func parseSimpleGET() throws {
        let requestString = "GET /hello?foo=bar HTTP/1.1\r\nHost: localhost\r\n\r\n"
        var parser = HTTPRequestParser()
        let result = try parser.parse(Data(requestString.utf8))

        guard case .request(let request, let remaining) = result else {
            Issue.record("Expected complete request")
            return
        }
        #expect(request.method == .get)
        #expect(request.path == "/hello")
        #expect(request.query == ["foo": "bar"])
        #expect(request.headers["Host"] == "localhost")
        #expect(remaining.isEmpty)
    }

    @Test
    func parsePOSTWithBody() throws {
        let body = "name=swift"
        let requestString = "POST /user HTTP/1.1\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        var parser = HTTPRequestParser()
        let result = try parser.parse(Data(requestString.utf8))

        guard case .request(let request, _) = result else {
            Issue.record("Expected complete request")
            return
        }
        #expect(request.method == .post)
        #expect(request.path == "/user")
        #expect(String(data: request.body, encoding: .utf8) == body)
    }

    @Test
    func needsMoreData() throws {
        let requestString = "GET /hello HTTP/1.1\r\nHost: localhost\r\n\r"
        var parser = HTTPRequestParser()
        let result = try parser.parse(Data(requestString.utf8))
        #expect(result == .needsMoreData)
    }

    @Test
    func rejectsInvalidRequestLine() {
        let requestString = "GET / HTTP/1.1 extra\r\nHost: localhost\r\n\r\n"
        var parser = HTTPRequestParser()
        #expect(throws: HTTPParserError.invalidRequestLine.self) {
            try parser.parse(Data(requestString.utf8))
        }
    }

    @Test
    func rejectsInvalidContentLength() {
        let requestString = "POST /user HTTP/1.1\r\nContent-Length: abc\r\n\r\n"
        var parser = HTTPRequestParser()
        #expect(throws: HTTPParserError.invalidContentLength.self) {
            try parser.parse(Data(requestString.utf8))
        }
    }

    @Test
    func rejectsMalformedHeader() {
        let requestString = "GET / HTTP/1.1\r\nMalformedHeader\r\n\r\n"
        var parser = HTTPRequestParser()
        #expect(throws: HTTPParserError.invalidHeader.self) {
            _ = try parser.parse(Data(requestString.utf8))
        }
    }

    @Test
    func parsesTwoPipelinedRequests() throws {
        var parser = HTTPRequestParser()
        let data = Data("GET /first HTTP/1.1\r\nHost: localhost\r\n\r\nGET /second HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".utf8)

        let first = try parser.parse(data)
        guard case .request(let request1, _) = first else {
            Issue.record("Expected first request")
            return
        }
        #expect(request1.path == "/first")

        let second = try parser.parse(Data())
        guard case .request(let request2, _) = second else {
            Issue.record("Expected second request")
            return
        }
        #expect(request2.path == "/second")
    }
}
