import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct RangeTests {
    @Test
    func parseClosedRange() throws {
        let range = try ByteRange("bytes=0-9")
        let resolved = range.resolvedRange(for: 100)
        #expect(resolved?.start == 0)
        #expect(resolved?.end == 9)
    }

    @Test
    func parseOpenEndedRange() throws {
        let range = try ByteRange("bytes=90-")
        let resolved = range.resolvedRange(for: 100)
        #expect(resolved?.start == 90)
        #expect(resolved?.end == 99)
    }

    @Test
    func parseSuffixRange() throws {
        let range = try ByteRange("bytes=-10")
        let resolved = range.resolvedRange(for: 100)
        #expect(resolved?.start == 90)
        #expect(resolved?.end == 99)
    }

    @Test
    func rejectsInvalidRange() {
        #expect(throws: RangeError.invalidRange.self) {
            try ByteRange("bytes=10-0")
        }
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

    @Test
    func responseEncoderReturns416ForInvalidRange() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString)
        let content = Data(String(repeating: "a", count: 100).utf8)
        try content.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let request = Request(
            method: .get,
            path: "/file",
            headers: HTTPHeaders([("Range", "bytes=200-300")]),
            body: Data()
        )
        let response = Response(file: fileURL)
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 416 Range Not Satisfiable"))
        #expect(string.contains("Content-Range: bytes */100"))
    }

    @Test
    func responseEncoderReturns416ForUnparseableRange() throws {
        let request = Request(
            method: .get,
            path: "/",
            headers: HTTPHeaders([("Range", "bytes=abc-xyz")]),
            body: Data()
        )
        let response = Response(text: "hello world")
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("HTTP/1.1 416 Range Not Satisfiable"))
        #expect(string.contains("Content-Range: bytes */11"))
    }
}
