import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct GzipTests {
    @Test
    func gzipCompressesAndDecompresses() throws {
        let original = Data("hello world hello world hello world".utf8)
        let compressed = try GzipCompressor.compress(original)
        #expect(compressed.count < original.count)

        let decompressed = try decompress(compressed)
        #expect(decompressed == original)
    }

    @Test
    func responseEncoderAppliesGzip() throws {
        let request = Request(
            method: .get,
            path: "/",
            headers: HTTPHeaders([("Accept-Encoding", "gzip")]),
            body: Data()
        )
        let response = Response(text: String(repeating: "a", count: 1000))
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(string.contains("Content-Encoding: gzip"))
    }

    private func decompress(_ data: Data) throws -> Data {
        var result = Data()
        let bufferSize = 64 * 1024
        let filter = try InputFilter(.decompress, using: .zlib) { _ in data }
        while true {
            var chunk = Data(count: bufferSize)
            let length = try filter.readData(into: &chunk)
            if length == 0 { break }
            result.append(chunk.prefix(length))
        }
        return result
    }
}
