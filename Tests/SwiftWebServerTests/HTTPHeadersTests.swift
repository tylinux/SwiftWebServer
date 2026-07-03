import Testing
@testable import SwiftWebServer

@Suite
struct HTTPHeadersTests {
    @Test
    func caseInsensitiveLookup() {
        var headers = HTTPHeaders()
        headers.set(name: "Content-Type", value: "application/json")
        #expect(headers["content-type"] == "application/json")
        #expect(headers["Content-Type"] == "application/json")
    }

    @Test
    func preservesOriginalCasingAndOrder() {
        var headers = HTTPHeaders()
        headers.add(name: "X-Custom-Header", value: "first")
        headers.add(name: "content-type", value: "text/plain")
        let lines = headers.allHeaderLines()
        #expect(lines.map(\.name) == ["X-Custom-Header", "content-type"])
    }

    @Test
    func addAccumulatesValues() {
        var headers = HTTPHeaders()
        headers.add(name: "Accept", value: "text/html")
        headers.add(name: "Accept", value: "application/json")
        #expect(headers.allValues(for: "Accept") == ["text/html", "application/json"])
    }

    @Test
    func setReplacesValues() {
        var headers = HTTPHeaders()
        headers.add(name: "Accept", value: "text/html")
        headers.set(name: "Accept", value: "application/json")
        #expect(headers.allValues(for: "Accept") == ["application/json"])
    }
}
