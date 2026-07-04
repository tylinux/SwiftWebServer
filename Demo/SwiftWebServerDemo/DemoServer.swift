import Foundation
import SwiftUI
import SwiftWebServer
import SwiftWebServerWebUpload

@MainActor
final class DemoServer: ObservableObject {
    @Published var status = "Stopped"
    @Published var url = "-"
    @Published var uploadURL = "-"
    @Published var isRunning = false

    /// Directory where WebUpload stores files.
    let uploadRoot: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let root = documents?.appendingPathComponent("WebUpload") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }()

    private var server: WebServer?

    func start() async {
        let server = WebServer()

        await server.addRoute(method: .get, path: "/hello") { _ in
            Response(text: "Hello from SwiftWebServer!")
        }

        await server.addRoute(method: .get, path: "/json") { _ in
            try Response(json: ["message": "Hello from SwiftWebServer!"])
        }

        await server.addRoute(
            method: .get,
            path: "/admin",
            authenticator: Authentication.basic { username, password in
                username == "admin" && password == "secret"
            }
        ) { _ in
            Response(text: "Admin area")
        }

        let webUpload = WebUpload(server: server, rootDirectory: uploadRoot)
        await webUpload.configure()

        do {
            try await server.start(port: 8080)
            if let port = await server.port {
                status = "Running on port \(port)"
                url = "http://localhost:\(port)/hello"
                uploadURL = "http://localhost:\(port)/upload"
                isRunning = true
            }
            self.server = server
        } catch {
            status = "Error: \(error.localizedDescription)"
            isRunning = false
        }
    }

    func stop() async {
        await server?.stop()
        server = nil
        status = "Stopped"
        url = "-"
        uploadURL = "-"
        isRunning = false
    }

    func suspend() async {
        await server?.suspend()
        status = "Suspended"
        isRunning = false
    }

    func resume() async {
        do {
            try await server?.resume()
            if let port = await server?.port {
                status = "Resumed on port \(port)"
                url = "http://localhost:\(port)/hello"
                uploadURL = "http://localhost:\(port)/upload"
                isRunning = true
            }
        } catch {
            status = "Resume error: \(error.localizedDescription)"
        }
    }
}
