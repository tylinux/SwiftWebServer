import Foundation
import Testing
@testable import SwiftWebServer
@testable import SwiftWebServerWebUpload

struct WebUploadTests {
    private func makeTempDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebServerWebUploadTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func multipartBody(fileName: String, content: String, boundary: String) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: text/plain\r\n\r\n".utf8))
        body.append(Data(content.utf8))
        body.append(Data("\r\n".utf8))
        body.append(Data("--\(boundary)--\r\n".utf8))
        return body
    }

    @Test
    func uploadAndDownloadFile() async throws {
        let root = try makeTempDirectory()
        let server = WebServer()
        let webUpload = WebUpload(server: server, rootDirectory: root)
        await webUpload.configure()

        try await server.start(port: 0)
        let port = try #require(await server.port)
        let baseURL = URL(string: "http://127.0.0.1:\(port)/upload")!

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(fileName: "hello.txt", content: "Hello, WebUpload!", boundary: boundary)

        let (_, uploadResponse) = try await URLSession.shared.data(for: request)
        let uploadHTTP = try #require(uploadResponse as? HTTPURLResponse)
        #expect(uploadHTTP.statusCode == 200)

        let downloadURL = URL(string: "http://127.0.0.1:\(port)/upload/files/hello.txt")!
        let (data, downloadResponse) = try await URLSession.shared.data(from: downloadURL)
        let downloadHTTP = try #require(downloadResponse as? HTTPURLResponse)
        #expect(downloadHTTP.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "Hello, WebUpload!")

        await server.stop()
    }

    @Test
    func listsUploadedFilesOnIndexPage() async throws {
        let root = try makeTempDirectory()
        let server = WebServer()
        let webUpload = WebUpload(server: server, rootDirectory: root)
        await webUpload.configure()

        try "File content".write(to: root.appendingPathComponent("existing.txt"), atomically: true, encoding: .utf8)

        try await server.start(port: 0)
        let port = try #require(await server.port)

        let url = URL(string: "http://127.0.0.1:\(port)/upload")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        let html = try #require(String(data: data, encoding: .utf8))
        #expect(html.contains("existing.txt"))

        await server.stop()
    }

    @Test
    func deleteUploadedFile() async throws {
        let root = try makeTempDirectory()
        try "data".write(to: root.appendingPathComponent("delete-me.txt"), atomically: true, encoding: .utf8)

        let server = WebServer()
        let webUpload = WebUpload(server: server, rootDirectory: root)
        await webUpload.configure()

        try await server.start(port: 0)
        let port = try #require(await server.port)

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/upload/files/delete-me.txt")!)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)

        let exists = FileManager.default.fileExists(atPath: root.appendingPathComponent("delete-me.txt").path)
        #expect(exists == false)

        await server.stop()
    }
}
