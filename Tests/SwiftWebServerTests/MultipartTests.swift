import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct MultipartTests {
    @Test
    func parseMultipartForm() throws {
        let bodyString = """
        ------WebKitFormBoundary\r\n\
        Content-Disposition: form-data; name="name"\r\n\
        \r\n\
        Swift\r\n\
        ------WebKitFormBoundary\r\n\
        Content-Disposition: form-data; name="file"; filename="hello.txt"\r\n\
        Content-Type: text/plain\r\n\
        \r\n\
        Hello\r\n\
        ------WebKitFormBoundary--\r\n
        """
        let request = Request(
            method: .post,
            path: "/upload",
            headers: HTTPHeaders([("Content-Type", "multipart/form-data; boundary=----WebKitFormBoundary")]),
            body: Data(bodyString.utf8)
        )

        let parts = try request.multipartParts()
        #expect(parts.count == 2)
        #expect(parts[0].name == "name")
        #expect(parts[0].stringValue == "Swift")
        #expect(parts[1].filename == "hello.txt")
    }

    @Test
    func parseMultipartWithQuotedBoundary() throws {
        let bodyString = """
        --boundary\r\n\
        Content-Disposition: form-data; name=text\r\n\
        \r\n\
        value\r\n\
        --boundary--\r\n
        """
        let request = Request(
            method: .post,
            path: "/upload",
            headers: HTTPHeaders([("Content-Type", "Multipart/Form-Data; boundary=\"boundary\"")]),
            body: Data(bodyString.utf8)
        )

        let parts = try request.multipartParts()
        #expect(parts.count == 1)
        #expect(parts[0].name == "text")
        #expect(parts[0].stringValue == "value")
    }

    @Test
    func rejectsMissingBoundary() {
        let request = Request(
            method: .post,
            path: "/upload",
            headers: HTTPHeaders([("Content-Type", "multipart/form-data")]),
            body: Data()
        )
        #expect(throws: MultipartError.missingBoundary.self) {
            try request.multipartParts()
        }
    }

    @Test
    func rejectsInvalidContentType() {
        let request = Request(
            method: .post,
            path: "/upload",
            headers: HTTPHeaders([("Content-Type", "text/plain")]),
            body: Data()
        )
        #expect(throws: MultipartError.invalidContentType.self) {
            try request.multipartParts()
        }
    }
}
