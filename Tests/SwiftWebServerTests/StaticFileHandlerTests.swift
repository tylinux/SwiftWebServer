import Foundation
import Testing
@testable import SwiftWebServer

struct StaticFileHandlerTests {
    private func makeTempDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebServerStaticTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func request(path: String) -> Request {
        Request(method: .get, path: path, pathParameters: ["path": path])
    }

    @Test
    func servesExistingFile() throws {
        let root = try makeTempDirectory()
        let file = root.appendingPathComponent("hello.txt")
        try "Hello".write(to: file, atomically: true, encoding: .utf8)

        let handler = StaticFileHandler(rootDirectory: root)
        let request = self.request(path: "hello.txt")
        let response = handler.response(for: request)

        #expect(response.status == .ok)
        if case .file(let url) = response.body {
            #expect(url.resolvingSymlinksInPath() == file.resolvingSymlinksInPath())
        } else {
            Issue.record("Expected file body")
        }
    }

    @Test
    func returnsNotFoundForMissingFile() throws {
        let root = try makeTempDirectory()
        let handler = StaticFileHandler(rootDirectory: root)
        let response = handler.response(for: request(path: "missing.txt"))
        #expect(response.status == .notFound)
    }

    @Test
    func preventsDirectoryTraversal() throws {
        let root = try makeTempDirectory()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString).txt")
        try "secret".write(to: outside, atomically: true, encoding: .utf8)

        let handler = StaticFileHandler(rootDirectory: root)
        let response = handler.response(for: request(path: "../\(outside.lastPathComponent)"))
        #expect(response.status == .notFound)

        try? FileManager.default.removeItem(at: outside)
    }

    @Test
    func servesIndexFileForDirectory() throws {
        let root = try makeTempDirectory()
        let subdir = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let index = subdir.appendingPathComponent("index.html")
        try "<h1>Index</h1>".write(to: index, atomically: true, encoding: .utf8)

        let handler = StaticFileHandler(rootDirectory: root)
        let response = handler.response(for: request(path: "docs"))

        #expect(response.status == .ok)
        if case .file(let url) = response.body {
            #expect(url.resolvingSymlinksInPath() == index.resolvingSymlinksInPath())
        } else {
            Issue.record("Expected index file body")
        }
    }

    @Test
    func returnsForbiddenForDirectoryWithoutIndex() throws {
        let root = try makeTempDirectory()
        let subdir = root.appendingPathComponent("secret")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)

        let handler = StaticFileHandler(rootDirectory: root)
        let response = handler.response(for: request(path: "secret"))
        #expect(response.status == .forbidden)
    }
}
