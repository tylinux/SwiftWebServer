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
                Button("Start Server") {
                    Task { await demoServer.start() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(demoServer.isRunning)

                Button("Stop Server") {
                    Task { await demoServer.stop() }
                }
                .buttonStyle(.bordered)
                .disabled(!demoServer.isRunning)
            }

            Text("Open the URL in a browser on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
    }
}
