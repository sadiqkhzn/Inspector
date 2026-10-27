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
        .commands {
            SearchCommands()
            BootWindowCommand()
        }

        Window("Boot items", id: "boot-items") {
            BootView()
        }
        .defaultSize(width: 760, height: 560)
    }
}

struct BootWindowCommand: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Divider()
            Button("Boot items") { openWindow(id: "boot-items") }
                .keyboardShortcut("b", modifiers: [.command, .option])
        }
    }
}

struct FocusSearchKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var focusSearch: (() -> Void)? {
        get { self[FocusSearchKey.self] }
        set { self[FocusSearchKey.self] = newValue }
    }
}

// The standard Edit › Find item owns ⌘F; replace it with one that focuses the toolbar search field.
struct SearchCommands: Commands {
    @FocusedValue(\.focusSearch) private var focusSearch

    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            Button("Find") { focusSearch?() }
                .keyboardShortcut("f")
                .disabled(focusSearch == nil)
        }
    }
}
