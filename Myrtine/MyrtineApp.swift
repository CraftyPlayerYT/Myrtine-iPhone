import SwiftUI

@main
@MainActor
struct MyrtineApp: App {
    @State private var environment: AppEnvironment

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        _environment = State(initialValue: AppEnvironment(
            inMemory: arguments.contains("-ui-testing"),
            useMocks: arguments.contains("-use-mocks")
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
                .preferredColorScheme(.light)
                .task { await environment.start() }
        }
    }
}
