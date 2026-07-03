import Testing
import Foundation
@testable import SwiftWebServer

@Suite
struct GzipTests {
    @Test
    func gzipCompressesAndProducesGzipFormat() throws {
        let original = Data(String(repeating: "hello world ", count: 100).utf8)
        let compressed = try GzipCompressor.compress(original)

        #expect(compressed.count < original.count)
        #expect(compressed.prefix(2) == Data([0x1f, 0x8b]))

        let decompressed = try decompressWithGunzip(compressed)
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
        guard let separatorRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            Issue.record("Missing header/body separator")
            return
        }
        let headerData = data.prefix(upTo: separatorRange.lowerBound)
        let bodyData = data.suffix(from: separatorRange.upperBound)
        let string = String(data: headerData, encoding: .utf8)!
        #expect(string.contains("Content-Encoding: gzip"))
        #expect(string.contains("Content-Length: \(bodyData.count)"))
        #expect(bodyData.prefix(2) == Data([0x1f, 0x8b]))

        let decompressed = try decompressWithGunzip(Data(bodyData))
        #expect(decompressed == Data(String(repeating: "a", count: 1000).utf8))
    }

    @Test
    func gzipIsDisabledWhenRangeIsPresent() throws {
        let request = Request(
            method: .get,
            path: "/",
            headers: HTTPHeaders([("Accept-Encoding", "gzip"), ("Range", "bytes=0-9")]),
            body: Data()
        )
        let response = Response(text: String(repeating: "a", count: 1000))
        let data = try ResponseEncoder().encode(response, for: request)
        let string = String(data: data, encoding: .utf8)!
        #expect(!string.contains("Content-Encoding: gzip"))
        #expect(string.contains("HTTP/1.1 206 Partial Content"))
    }

    private func decompressWithGunzip(_ data: Data) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe

        try process.run()
        inputPipe.fileHandleForWriting.write(data)
        try inputPipe.fileHandleForWriting.close()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GzipError.compressionFailed
        }

        return outputPipe.fileHandleForReading.readDataToEndOfFile()
    }
}
