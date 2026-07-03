import Foundation
import Compression

public enum GzipCompressor {
    public static func compress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { return Data() }

        var output = Data()
        let bufferSize = 64 * 1024
        var sourceIndex = 0

        let filter = try OutputFilter(.compress, using: .zlib, bufferCapacity: bufferSize) { chunk in
            if let chunk {
                output.append(chunk)
            }
        }

        while sourceIndex < data.count {
            let chunkSize = min(bufferSize, data.count - sourceIndex)
            let chunk = data.subdata(in: sourceIndex..<sourceIndex + chunkSize)
            try filter.write(chunk)
            sourceIndex += chunkSize
        }

        try filter.finalize()
        return output
    }
}

public enum GzipError: Error, Sendable {
    case compressionFailed
}
