import Foundation
import zlib

public enum GzipCompressor {
    public static func compress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let result = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            31, // 15 + 16 => gzip format
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard result == Z_OK else {
            throw GzipError.compressionFailed
        }
        defer { deflateEnd(&stream) }

        var output = Data()
        let bufferSize = 64 * 1024

        let status = data.withUnsafeBytes { sourcePtr -> Int32 in
            guard let sourceAddress = sourcePtr.bindMemory(to: UInt8.self).baseAddress else {
                return Z_STREAM_ERROR
            }
            stream.next_in = UnsafeMutablePointer<UInt8>(mutating: sourceAddress)
            stream.avail_in = uInt(data.count)

            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var finished = false
            repeat {
                let written = buffer.withUnsafeMutableBufferPointer { bufferPtr -> Int in
                    guard let baseAddress = bufferPtr.baseAddress else { return -1 }
                    stream.next_out = baseAddress
                    stream.avail_out = uInt(bufferSize)
                    let deflateStatus = deflate(&stream, Z_FINISH)
                    guard deflateStatus == Z_OK || deflateStatus == Z_STREAM_END else {
                        return Int(deflateStatus)
                    }
                    if deflateStatus == Z_STREAM_END {
                        finished = true
                    }
                    return bufferSize - Int(stream.avail_out)
                }
                if written < 0 {
                    return Z_STREAM_ERROR
                }
                output.append(buffer, count: written)
            } while !finished && stream.avail_out == 0

            return Z_OK
        }

        guard status == Z_OK else {
            throw GzipError.compressionFailed
        }

        return output
    }
}

public enum GzipError: Error, Sendable {
    case compressionFailed
}
