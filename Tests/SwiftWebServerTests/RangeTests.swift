import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RangeTests {
    @Test
    func parseRangeHeader() throws {
        let range = try ByteRange("bytes=0-9")
        #expect(range.start == 0)
        #expect(range.end == 9)
    }

    @Test
    func responseEncoderHandlesRange() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        let content = Data(String(repeating: "a", count: 100).utf8)
        try content.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let request = Request(
            method: .get,
            path: "/file",
            headers: HTTPHeaders([("Range", "bytes=0-9")]),
            body: Data()
        )
        let response = Response(file: fileURL)
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 206 Partial Content"))
        #expect(string.contains("Content-Range: bytes 0-9/100"))
        #expect(string.hasSuffix("aaaaaaaaaa"))
    }
}
