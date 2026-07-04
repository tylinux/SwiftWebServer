import SwiftUI

@main
struct SwiftWebServerDemoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Forward lifecycle events to the shared demo server via notifications.
            switch newPhase {
            case .background:
                NotificationCenter.default.post(name: .demoServerSuspend, object: nil)
            case .active:
                NotificationCenter.default.post(name: .demoServerResume, object: nil)
            default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let demoServerSuspend = Notification.Name("demoServerSuspend")
    static let demoServerResume = Notification.Name("demoServerResume")
}
