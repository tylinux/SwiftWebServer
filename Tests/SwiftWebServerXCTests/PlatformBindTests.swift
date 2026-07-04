import XCTest
import Foundation
@testable import SwiftWebServer

final class PlatformBindTests: XCTestCase {
    func testServerBindsToEphemeralPortAndResponds() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/echo") { request in
            Response(text: "echo:\(request.query["q"] ?? "")")
        }

        try await server.start(port: 0)
        let port = await server.port
        let boundPort = try XCTUnwrap(port)
        XCTAssertGreaterThan(boundPort, 0)

        let url = URL(string: "http://127.0.0.1:\(boundPort)/echo?q=hi")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "echo:hi")

        await server.stop()
        let runningAfterStop = await server.isRunning
        XCTAssertFalse(runningAfterStop)
    }

    func testServerCanRestartOnPreviouslyAssignedPort() async throws {
        let server = WebServer()
        await server.addRoute(method: .get, path: "/") { _ in
            Response(text: "ok")
        }

        try await server.start(port: 0)
        let restartPort = await server.port
        let assignedPort = try XCTUnwrap(restartPort)
        await server.stop()

        // Briefly wait for the socket to be released.
        try await Task.sleep(nanoseconds: 50_000_000)

        try await server.start(port: assignedPort)
        let url = URL(string: "http://127.0.0.1:\(assignedPort)/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")

        await server.stop()
        let runningAfterStop = await server.isRunning
        XCTAssertFalse(runningAfterStop)
    }
}
