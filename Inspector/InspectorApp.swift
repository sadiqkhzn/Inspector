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
            ModeCommands()
        }
    }
}

struct InspectorModeKey: FocusedValueKey {
    typealias Value = Binding<InspectorMode>
}

extension FocusedValues {
    var inspectorMode: Binding<InspectorMode>? {
        get { self[InspectorModeKey.self] }
        set { self[InspectorModeKey.self] = newValue }
    }
}

// View ▸ Storage (⌘1) / Boot (⌘2), like Finder and Mail.
struct ModeCommands: Commands {
    @FocusedBinding(\.inspectorMode) private var mode

    var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(InspectorMode.allCases) { option in
                Button(option.title) { mode = option }
                    .keyboardShortcut(option.shortcut, modifiers: .command)
                    .disabled(mode == nil)
            }
            Divider()
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
