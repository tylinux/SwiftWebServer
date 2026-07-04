import SwiftUI

struct ContentView: View {
    @StateObject private var demoServer = DemoServer()

    var body: some View {
        VStack(spacing: 20) {
            Text("SwiftWebServer Demo")
                .font(.largeTitle)

            Label("Status: \(demoServer.status)", systemImage: "network")
            Text("URL: \(demoServer.url)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Start") {
                    Task { await demoServer.start() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(demoServer.isRunning)

                Button("Suspend") {
                    Task { await demoServer.suspend() }
                }
                .disabled(!demoServer.isRunning)

                Button("Resume") {
                    Task { await demoServer.resume() }
                }
                .disabled(demoServer.isRunning)

                Button("Stop") {
                    Task { await demoServer.stop() }
                }
                .buttonStyle(.bordered)
                .disabled(!demoServer.isRunning && !demoServer.status.contains("Suspended"))
            }

            Text("Open the URL in a browser on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
        .onReceive(NotificationCenter.default.publisher(for: .demoServerSuspend)) { _ in
            Task { await demoServer.suspend() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .demoServerResume)) { _ in
            Task { await demoServer.resume() }
        }
    }
}
