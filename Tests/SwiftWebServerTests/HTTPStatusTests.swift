import Testing
@testable import SwiftWebServer

@Suite
struct HTTPStatusTests {
    @Test
    func reasonPhrases() {
        #expect(HTTPStatus.continue.reasonPhrase == "Continue")
        #expect(HTTPStatus.ok.reasonPhrase == "OK")
        #expect(HTTPStatus.created.reasonPhrase == "Created")
        #expect(HTTPStatus.noContent.reasonPhrase == "No Content")
        #expect(HTTPStatus.movedPermanently.reasonPhrase == "Moved Permanently")
        #expect(HTTPStatus.found.reasonPhrase == "Found")
        #expect(HTTPStatus.notModified.reasonPhrase == "Not Modified")
        #expect(HTTPStatus.badRequest.reasonPhrase == "Bad Request")
        #expect(HTTPStatus.unauthorized.reasonPhrase == "Unauthorized")
        #expect(HTTPStatus.forbidden.reasonPhrase == "Forbidden")
        #expect(HTTPStatus.notFound.reasonPhrase == "Not Found")
        #expect(HTTPStatus.methodNotAllowed.reasonPhrase == "Method Not Allowed")
        #expect(HTTPStatus.rangeNotSatisfiable.reasonPhrase == "Range Not Satisfiable")
        #expect(HTTPStatus.imATeapot.reasonPhrase == "I'm a teapot")
        #expect(HTTPStatus.internalServerError.reasonPhrase == "Internal Server Error")
        #expect(HTTPStatus.notImplemented.reasonPhrase == "Not Implemented")
        #expect(HTTPStatus.badGateway.reasonPhrase == "Bad Gateway")
        #expect(HTTPStatus.serviceUnavailable.reasonPhrase == "Service Unavailable")
        #expect(HTTPStatus(code: 999).reasonPhrase == "")
    }

    @Test
    func staticConstants() {
        #expect(HTTPStatus.continue.code == 100)
        #expect(HTTPStatus.ok.code == 200)
        #expect(HTTPStatus.created.code == 201)
        #expect(HTTPStatus.noContent.code == 204)
        #expect(HTTPStatus.movedPermanently.code == 301)
        #expect(HTTPStatus.found.code == 302)
        #expect(HTTPStatus.notModified.code == 304)
        #expect(HTTPStatus.badRequest.code == 400)
        #expect(HTTPStatus.unauthorized.code == 401)
        #expect(HTTPStatus.forbidden.code == 403)
        #expect(HTTPStatus.notFound.code == 404)
        #expect(HTTPStatus.methodNotAllowed.code == 405)
        #expect(HTTPStatus.rangeNotSatisfiable.code == 416)
        #expect(HTTPStatus.imATeapot.code == 418)
        #expect(HTTPStatus.internalServerError.code == 500)
        #expect(HTTPStatus.notImplemented.code == 501)
        #expect(HTTPStatus.badGateway.code == 502)
        #expect(HTTPStatus.serviceUnavailable.code == 503)
    }

    @Test
    func equalityAndHashable() {
        let a = HTTPStatus(code: 404)
        let b = HTTPStatus(code: 404)
        let c = HTTPStatus(code: 200)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
        #expect(HTTPStatus.ok == HTTPStatus(code: 200))
    }
}
