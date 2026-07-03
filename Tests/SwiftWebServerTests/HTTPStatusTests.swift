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
        #expect(HTTPStatus(code: 999).reasonPhrase == "")
    }

    @Test
    func staticConstants() {
        #expect(HTTPStatus.ok.code == 200)
        #expect(HTTPStatus.created.code == 201)
        #expect(HTTPStatus.noContent.code == 204)
        #expect(HTTPStatus.badRequest.code == 400)
        #expect(HTTPStatus.unauthorized.code == 401)
        #expect(HTTPStatus.forbidden.code == 403)
        #expect(HTTPStatus.notFound.code == 404)
        #expect(HTTPStatus.methodNotAllowed.code == 405)
        #expect(HTTPStatus.rangeNotSatisfiable.code == 416)
        #expect(HTTPStatus.imATeapot.code == 418)
        #expect(HTTPStatus.internalServerError.code == 500)
    }

    @Test
    func equalityAndHashable() {
        let a = HTTPStatus(code: 404)
        let b = HTTPStatus(code: 404)
        let c = HTTPStatus(code: 200)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }
}
