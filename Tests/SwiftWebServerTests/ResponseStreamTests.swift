import Foundation
import Testing
@testable import SwiftWebServer

struct ResponseStreamTests {
    private func makeStream(_ chunks: [String]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(Data(chunk.utf8))
            }
            continuation.finish()
        }
    }

    @Test
    func encodesChunkedResponse() throws {
        let stream = makeStream(["Hello", " ", "World"])
        let response = Response(stream: stream)
        let request = Request(method: .get, path: "/")

        let encoded = try ResponseEncoder().encodeResponse(response, for: request)
        guard case .chunked(let headers, _) = encoded else {
            Issue.record("Expected chunked response")
            return
        }

        let headerString = try #require(String(data: headers, encoding: .utf8))
        #expect(headerString.contains("HTTP/1.1 200 OK"))
        #expect(headerString.contains("Transfer-Encoding: chunked"))
        #expect(!headerString.contains("Content-Length"))
    }

    @Test
    func rejectsEncodeForStreamBody() {
        let stream = makeStream(["a"])
        let response = Response(stream: stream)
        let request = Request(method: .get, path: "/")

        #expect(throws: ResponseEncoderError.streamResponseMustBeSentChunked) {
            _ = try ResponseEncoder().encode(response, for: request)
        }
    }

    @Test
    func headRequestOnStreamSendsHeadersOnly() throws {
        let stream = makeStream(["ignored"])
        let response = Response(stream: stream)
        let request = Request(method: .head, path: "/")

        let encoded = try ResponseEncoder().encodeResponse(response, for: request)
        guard case .complete(let data) = encoded else {
            Issue.record("Expected complete headers for HEAD")
            return
        }

        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("Transfer-Encoding: chunked"))
        #expect(text.hasSuffix("\r\n\r\n"))
    }
}
