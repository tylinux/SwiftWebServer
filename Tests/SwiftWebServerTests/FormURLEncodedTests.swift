import Foundation
import Testing
@testable import SwiftWebServer

struct FormURLEncodedTests {
    private func request(body: String, contentType: String = "application/x-www-form-urlencoded") -> Request {
        Request(
            method: .post,
            path: "/",
            headers: HTTPHeaders([("Content-Type", contentType)]),
            body: Data(body.utf8)
        )
    }

    @Test
    func parsesSimpleFields() throws {
        let request = request(body: "name=Alice&age=30")
        let fields = try request.formFields()
        #expect(fields["name"] == "Alice")
        #expect(fields["age"] == "30")
    }

    @Test
    func decodesPercentEncoding() throws {
        let request = request(body: "name=Hello%20World&path=%2Ffoo%2Fbar")
        let fields = try request.formFields()
        #expect(fields["name"] == "Hello World")
        #expect(fields["path"] == "/foo/bar")
    }

    @Test
    func decodesPlusAsSpace() throws {
        let request = request(body: "query=hello+world")
        let fields = try request.formFields()
        #expect(fields["query"] == "hello world")
    }

    @Test
    func handlesEmptyValue() throws {
        let request = request(body: "key=")
        let fields = try request.formFields()
        #expect(fields["key"] == "")
    }

    @Test
    func handlesMissingEquals() throws {
        let request = request(body: "flag")
        let fields = try request.formFields()
        #expect(fields["flag"] == "")
    }

    @Test
    func lastValueWinsForDuplicateKeys() throws {
        let request = request(body: "tag=swift&tag=server")
        let fields = try request.formFields()
        #expect(fields["tag"] == "server")
    }

    @Test
    func rejectsMissingContentType() {
        let request = Request(method: .post, path: "/", body: Data("a=b".utf8))
        #expect(throws: FormURLEncodedError.missingContentType) {
            _ = try request.formFields()
        }
    }

    @Test
    func acceptsContentTypeWithCharset() throws {
        let request = request(body: "a=b", contentType: "application/x-www-form-urlencoded; charset=utf-8")
        let fields = try request.formFields()
        #expect(fields["a"] == "b")
    }
}
