import Testing
import Foundation
import zlib
@testable import SwiftWebServer

@Suite
struct GzipTests {
    @Test
    func gzipCompressesAndDecompresses() throws {
        let original = Data(String(repeating: "hello world ", count: 100).utf8)
        let compressed = try GzipCompressor.compress(original)
        #expect(compressed.count < original.count)
        #expect(compressed.prefix(2) == Data([0x1f, 0x8b]))

        let decompressed = try decompressGzip(compressed)
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

        let headerString = String(data: headerData, encoding: .utf8)!
        #expect(headerString.contains("Content-Encoding: gzip"))
        #expect(headerString.contains("Content-Length: \(bodyData.count)"))
        #expect(bodyData.prefix(2) == Data([0x1f, 0x8b]))

        let decompressed = try decompressGzip(Data(bodyData))
        #expect(decompressed == Data(String(repeating: "a", count: 1000).utf8))
    }

    @Test
    func gzipSkippedWhenRangePresent() throws {
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
    }

    private func decompressGzip(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let result = inflateInit2_(
            &stream,
            31, // 15 + 16 => gzip format
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard result == Z_OK else {
            throw GzipError.compressionFailed
        }
        defer { inflateEnd(&stream) }

        var output = Data()
        let bufferSize = 64 * 1024

        let status = data.withUnsafeBytes { sourcePtr -> Int32 in
            guard let sourceAddress = sourcePtr.bindMemory(to: UInt8.self).baseAddress else {
                return Z_STREAM_ERROR
            }
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: sourceAddress)
            stream.avail_in = uInt(data.count)

            var buffer = [UInt8](repeating: 0, count: bufferSize)
            repeat {
                let written = buffer.withUnsafeMutableBufferPointer { bufferPtr -> Int in
                    guard let baseAddress = bufferPtr.baseAddress else { return -1 }
                    stream.next_out = baseAddress
                    stream.avail_out = uInt(bufferSize)
                    let inflateStatus = inflate(&stream, Z_NO_FLUSH)
                    guard inflateStatus == Z_OK || inflateStatus == Z_STREAM_END else {
                        return Int(inflateStatus)
                    }
                    return bufferSize - Int(stream.avail_out)
                }
                if written < 0 {
                    return Z_STREAM_ERROR
                }
                output.append(buffer, count: written)
            } while stream.avail_out == 0

            return Z_OK
        }

        guard status == Z_OK else {
            throw GzipError.compressionFailed
        }

        return output
    }
}
