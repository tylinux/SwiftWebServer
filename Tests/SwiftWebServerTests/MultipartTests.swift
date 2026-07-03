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
}
