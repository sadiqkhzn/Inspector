import SwiftUI

@main
struct InspectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
