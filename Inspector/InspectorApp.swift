import SwiftUI

@main
struct InspectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 820, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 760)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
