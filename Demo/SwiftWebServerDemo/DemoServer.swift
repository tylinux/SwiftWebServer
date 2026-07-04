import Foundation
import SwiftUI
import SwiftWebServer

@MainActor
final class DemoServer: ObservableObject {
    @Published var status = "Stopped"
    @Published var url = "-"
    @Published var isRunning = false

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

        do {
            try await server.start(port: 8080)
            if let port = await server.port {
                status = "Running on port \(port)"
                url = "http://localhost:\(port)/hello"
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
        isRunning = false
    }
}
