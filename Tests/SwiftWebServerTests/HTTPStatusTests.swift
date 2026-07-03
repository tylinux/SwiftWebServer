import Testing
@testable import SwiftWebServer

@Suite
struct HTTPStatusTests {
    @Test
    func reasonPhrases() {
        #expect(HTTPStatus.ok.reasonPhrase == "OK")
        #expect(HTTPStatus.notFound.reasonPhrase == "Not Found")
        #expect(HTTPStatus.internalServerError.reasonPhrase == "Internal Server Error")
        #expect(HTTPStatus(code: 418).reasonPhrase == "I'm a teapot")
    }
}
