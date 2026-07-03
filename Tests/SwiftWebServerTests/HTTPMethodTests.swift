import Testing
@testable import SwiftWebServer

@Suite
struct HTTPMethodTests {
    @Test
    func equalityIsCaseInsensitive() {
        let get1 = HTTPMethod(rawValue: "GET")
        let get2 = HTTPMethod(rawValue: "get")
        #expect(get1 == get2)
        #expect(get1.rawValue == "GET")
    }

    @Test
    func staticMethods() {
        #expect(HTTPMethod.get == HTTPMethod(rawValue: "GET"))
        #expect(HTTPMethod.post == HTTPMethod(rawValue: "POST"))
        #expect(HTTPMethod.put == HTTPMethod(rawValue: "PUT"))
        #expect(HTTPMethod.delete == HTTPMethod(rawValue: "DELETE"))
        #expect(HTTPMethod.head == HTTPMethod(rawValue: "HEAD"))
        #expect(HTTPMethod.options == HTTPMethod(rawValue: "OPTIONS"))
        #expect(HTTPMethod.patch == HTTPMethod(rawValue: "PATCH"))
    }
}
