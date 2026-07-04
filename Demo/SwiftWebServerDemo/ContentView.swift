import SwiftUI

struct ContentView: View {
    @StateObject private var demoServer = DemoServer()
    @State private var showUploadedFiles = false

    var body: some View {
        VStack(spacing: 20) {
            Text("SwiftWebServer Demo")
                .font(.largeTitle)

            Label("Status: \(demoServer.status)", systemImage: "network")

            VStack(spacing: 4) {
                Text("Hello URL: \(demoServer.url)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let uploadURL = URL(string: demoServer.uploadURL) {
                    Link("Open Upload Page: \(demoServer.uploadURL)", destination: uploadURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Upload URL: \(demoServer.uploadURL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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

            Button("View Uploaded Files") {
                showUploadedFiles = true
            }
            .disabled(!demoServer.isRunning)

            Text("Open the URL in a browser on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 240)
        .sheet(isPresented: $showUploadedFiles) {
            UploadedFilesView(uploadRoot: demoServer.uploadRoot)
        }
        .onReceive(NotificationCenter.default.publisher(for: .demoServerSuspend)) { _ in
            Task { await demoServer.suspend() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .demoServerResume)) { _ in
            Task { await demoServer.resume() }
        }
    }
}
