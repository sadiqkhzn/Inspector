import SwiftUI
import AppKit
import QuickLook

@MainActor
final class StorageViewModel: ObservableObject {
    struct TrashReceipt: Identifiable {
        struct Moved {
            let item: CleanupItem
            let trashedURL: URL?
        }

        let id = UUID()
        let moved: [Moved]
        let failed: [String]

        var bytes: Int64 { moved.reduce(0) { $0 + $1.item.bytes } }
        var canUndo: Bool { moved.contains { $0.trashedURL != nil } }
    }

    @Published var items: [CleanupItem] = []
    @Published private(set) var disk = DiskSnapshot(totalBytes: 0, freeBytes: 0)
    @Published private(set) var isScanning = false
    @Published private(set) var hasScanned = false
    @Published var tierFilter: SafetyLevel? = nil { didSet { keepFocusVisible() } }
    @Published var searchText: String = "" { didSet { keepFocusVisible() } }
    @Published var focusedID: CleanupItem.ID?
    @Published var receipt: TrashReceipt?
    @Published var errorMessage: String?

    var visibleItems: [CleanupItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            (tierFilter == nil || item.safety == tierFilter) &&
            (query.isEmpty
                || item.name.localizedCaseInsensitiveContains(query)
                || item.owner.name.localizedCaseInsensitiveContains(query)
                || item.path.localizedCaseInsensitiveContains(query))
        }
    }

    var selectedItems: [CleanupItem] { items.filter(\.selected) }
    var selectedBytes: Int64 { total(selectedItems) }
    var foundBytes: Int64 { total(items) }
    var focusedItem: CleanupItem? { items.first { $0.id == focusedID } }

    func bytes(for tier: SafetyLevel) -> Int64 { total(items.filter { $0.safety == tier }) }
    func count(for tier: SafetyLevel?) -> Int { items.filter { tier == nil || $0.safety == tier }.count }

    func refresh() async {
        isScanning = true
        disk = Scanner.diskSnapshot()
        let previouslySelected = Set(selectedItems.map(\.id))
        let scanned = await Scanner.scan()
        items = scanned.map { item in
            var item = item
            item.selected = previouslySelected.contains(item.id)
            return item
        }
        if focusedItem == nil { focusedID = visibleItems.first?.id }
        isScanning = false
        hasScanned = true
    }

    /// Lightweight update that only re-reads disk free / total — no catalog scan.
    /// Scanner.diskSnapshot is a single syscall (~1-2 ms, no disk I/O), so this
    /// is safe to call on a 1-second interval. Called by a background poll in
    /// ContentView so the header stays live when space is freed outside Inspector
    /// (Trash emptied, downloads deleted, brew cleanup, etc.) without triggering
    /// an expensive catalog rescan.
    func pollDiskOnly() {
        disk = Scanner.diskSnapshot()
    }

    func toggle(_ id: CleanupItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].selected.toggle()
    }

    func selectAllSafe() {
        let visible = Set(visibleItems.map(\.id))
        for i in items.indices where items[i].safety == .safe && visible.contains(items[i].id) {
            items[i].selected = true
        }
    }

    func clearSelection() {
        for i in items.indices { items[i].selected = false }
    }

    func moveFocus(by offset: Int) {
        let ids = visibleItems.map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = focusedID, let index = ids.firstIndex(of: current) else {
            focusedID = ids.first
            return
        }
        focusedID = ids[min(max(index + offset, 0), ids.count - 1)]
    }

    func moveSelectedToTrash() {
        let chosen = selectedItems
        guard !chosen.isEmpty else { return }
        var moved: [TrashReceipt.Moved] = []
        var failed: [String] = []
        for item in chosen {
            do {
                let trashedURL = try Scanner.moveToTrash(item)
                moved.append(.init(item: item, trashedURL: trashedURL))
            } catch {
                failed.append(item.name)
            }
        }

        let movedIDs = Set(moved.map(\.item.id))
        if let focusedID, movedIDs.contains(focusedID) {
            let ids = visibleItems.map(\.id)
            let start = ids.firstIndex(of: focusedID) ?? 0
            self.focusedID = (Array(ids[start...]) + ids[..<start].reversed()).first { !movedIDs.contains($0) }
        }
        items.removeAll { movedIDs.contains($0.id) }
        disk = Scanner.diskSnapshot()
        receipt = TrashReceipt(moved: moved, failed: failed)
    }

    func undoLastTrash() {
        guard let receipt else { return }
        var restored: [CleanupItem] = []
        var failed: [String] = []
        for entry in receipt.moved {
            guard let trashedURL = entry.trashedURL else {
                failed.append(entry.item.name)
                continue
            }
            do {
                try Scanner.restore(entry.item, from: trashedURL)
                restored.append(entry.item)
            } catch {
                failed.append(entry.item.name)
            }
        }
        items = Scanner.sorted(items + restored)
        focusedID = restored.first?.id ?? focusedID
        disk = Scanner.diskSnapshot()
        self.receipt = nil
        if !failed.isEmpty {
            errorMessage = "Couldn't put back \(failed.joined(separator: ", ")). They're still in the Trash."
        }
    }

    /// When a search or filter hides the focused item, the details pane follows the first visible one.
    private func keepFocusVisible() {
        let visible = visibleItems
        if !visible.contains(where: { $0.id == focusedID }) { focusedID = visible.first?.id }
    }

    private func total(_ items: [CleanupItem]) -> Int64 {
        items.reduce(0) { $0 + $1.bytes }
    }
}

// MARK: - Design tokens

private extension SafetyLevel {
    var tint: Color {
        switch self {
        case .safe:   return Color(nsColor: .systemIndigo)
        case .review: return Color(nsColor: .systemOrange)
        // Keep is deliberately neutral: it's shown for visibility, not as a threat.
        case .keep:   return Color(nsColor: .systemGray)
        }
    }

    var note: String {
        switch self {
        case .safe:   return "Rebuilt automatically when needed. Removing it costs nothing meaningful."
        case .review: return "Holds real state. Usually fine to remove, but know the trade-off."
        case .keep:   return "Your data or working state. Shown so you can see it, not suggested."
        }
    }
}

func motion(_ reduceMotion: Bool, _ animation: Animation = .smooth(duration: 0.22)) -> Animation? {
    reduceMotion ? nil : animation
}

private func splitSize(_ formatted: String) -> (value: String, unit: String) {
    guard let i = formatted.lastIndex(where: { $0.isWhitespace }) else { return (formatted, "") }
    return (String(formatted[..<i]), String(formatted[formatted.index(after: i)...]))
}

private func reveal(_ item: CleanupItem) {
    NSWorkspace.shared.activateFileViewerSelecting([item.url])
}

// MARK: - Root

/// The domains Inspector shows, as sibling panels inside one window.
enum InspectorMode: String, CaseIterable, Identifiable {
    case storage
    case boot
    case permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .storage:     return "Storage"
        case .boot:        return "Boot"
        case .permissions: return "Permissions"
        }
    }

    var symbol: String {
        switch self {
        case .storage:     return "internaldrive"
        case .boot:        return "power"
        case .permissions: return "hand.raised"
        }
    }

    var shortcut: KeyEquivalent {
        switch self {
        case .storage:     return "1"
        case .boot:        return "2"
        case .permissions: return "3"
        }
    }

    var searchPrompt: String {
        switch self {
        case .storage:     return "Filter by name, path or app"
        case .boot:        return "Filter by label, app or program"
        case .permissions: return "Filter by app"
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = StorageViewModel()
    @StateObject private var boot = BootViewModel()
    @StateObject private var permissions = PermissionsViewModel()
    @SceneStorage("mode") private var mode: InspectorMode = .storage
    // Closed until the user asks for it: clicking a row, the toolbar toggle, or ⌥⌘I.
    @State private var showDetails = false
    @FocusState private var searchFocused: Bool
    @State private var confirmTrash = false
    @State private var quickLookURL: URL?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // A plain column rather than `.inspector`, which claims the trailing end of the
        // toolbar; this keeps one full-width toolbar above both the list and the details.
        HStack(spacing: 0) {
            Group {
                switch mode {
                case .storage:
                    content
                case .boot:
                    BootContent(
                        vm: boot,
                        onOpenDetails: { if !showDetails { setDetails(visible: true) } },
                        onQuickLook: { quickLookURL = $0.plistURL }
                    )
                case .permissions:
                    PermissionsView(
                        vm: permissions,
                        onOpenDetails: { if !showDetails { setDetails(visible: true) } }
                    )
                }
            }
            .transition(.opacity)
            if showDetails {
                Divider()
                detailsPane
                    .frame(width: 320)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .transition(.move(edge: .trailing))
            }
        }
        .navigationTitle("Inspector")
        .toolbar { toolbar }
        .background {
            ShortcutButton(key: "i", modifiers: [.command, .option]) { setDetails(visible: !showDetails) }
        }
        .focusedSceneValue(\.focusSearch, focusSearch)
        .focusedSceneValue(\.inspectorMode, $mode)
        .animation(motion(reduceMotion, .easeOut(duration: 0.15)), value: mode)
        // Each tab has its own details, so switching tabs starts with the pane closed.
        .onChange(of: mode) { _, _ in
            if showDetails { setDetails(visible: false) }
        }
        .quickLookPreview($quickLookURL)
        .confirmationDialog(
            "Move \(vm.selectedItems.count) items to the Trash?",
            isPresented: $confirmTrash,
            titleVisibility: .visible
        ) {
            Button("Move to Trash") { trash() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your selection includes items marked Review or Keep. You can put everything back with Undo, or from the Trash.")
        }
        .alert(
            "Something didn't work",
            isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .task {
            boot.load()
            await vm.refresh()
        }
        // The disk numbers only appear in Storage, so the 1-second poll runs only there.
        .task(id: mode) {
            guard mode == .storage else { return }
            vm.pollDiskOnly()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                vm.pollDiskOnly()
            }
        }
    }

    @ViewBuilder
    private var detailsPane: some View {
        switch mode {
        case .storage:
            DetailsPane(
                item: vm.focusedItem,
                foundBytes: vm.foundBytes,
                onToggle: { if let id = vm.focusedID { withAnimation(motion(reduceMotion)) { vm.toggle(id) } } },
                onReveal: { if let item = vm.focusedItem { reveal(item) } },
                onQuickLook: { quickLookURL = vm.focusedItem?.url },
                onClose: { setDetails(visible: false) }
            )
        case .boot:
            BootDetailsPane(
                item: boot.focusedItem,
                onQuickLook: { quickLookURL = boot.focusedItem?.plistURL },
                onClose: { setDetails(visible: false) }
            )
        case .permissions:
            PermissionsDetailsPane(
                app: permissions.focused,
                onClose: { setDetails(visible: false) }
            )
        }
    }

    private var searchText: Binding<String> {
        switch mode {
        case .storage:     return $vm.searchText
        case .boot:        return $boot.searchText
        case .permissions: return $permissions.searchText
        }
    }

    private func rescan() {
        switch mode {
        case .storage:     Task { await vm.refresh() }
        case .boot:        withAnimation(motion(reduceMotion)) { boot.load() }
        case .permissions: Task { await permissions.load() }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ModeTabs(selection: $mode)
        }
        ToolbarItem(placement: .principal) {
            ToolbarSearchField(text: searchText, prompt: mode.searchPrompt, isFocused: $searchFocused)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                rescan()
            } label: {
                if mode == .storage && vm.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
            }
            .help("Rescan  ⌘R")
            .keyboardShortcut("r")
            .disabled(mode == .storage && vm.isScanning)

            Button {
                setDetails(visible: !showDetails)
            } label: {
                Label(showDetails ? "Hide Details" : "Show Details", systemImage: "sidebar.right")
            }
            .help(showDetails ? "Hide details  ⌥⌘I" : "Show details  ⌥⌘I")
        }
    }

    private func focusSearch() {
        searchFocused = true
        // Focus can't always cross into a toolbar item, so also hand the field first responder directly.
        DispatchQueue.main.async { focusToolbarTextField() }
    }

    private func setDetails(visible: Bool) {
        withAnimation(motion(reduceMotion)) { showDetails = visible }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if !vm.hasScanned {
                ScanningState()
            } else if vm.items.isEmpty {
                EmptyState { Task { await vm.refresh() } }
            } else {
                OverviewHeader(vm: vm)
                filterBar
                if vm.visibleItems.isEmpty {
                    noMatches
                } else {
                    ItemList(
                        vm: vm,
                        onQuickLook: { quickLookURL = $0.url },
                        onOpenDetails: { if !showDetails { setDetails(visible: true) } },
                        bottomInset: barState == 0 ? 12 : 84
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(alignment: .bottom) { floatingBar }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            PillPicker(
                selection: $vm.tierFilter,
                options: ([nil] + SafetyLevel.allCases.map { Optional($0) }).map { (value: $0, label: $0?.label ?? "All", count: vm.count(for: $0)) }
            )
            Spacer(minLength: 12)
            ViewThatFits(in: .horizontal) {
                Text(vm.tierFilter == nil ? "Safest first, then largest" : "Largest first")
                Text("")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("Select All Safe") {
                withAnimation(motion(reduceMotion)) { vm.selectAllSafe() }
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(!vm.visibleItems.contains { $0.safety == .safe && !$0.selected })
        }
        .padding(.leading, 26)
        .padding(.trailing, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var noMatches: some View {
        if !vm.searchText.isEmpty {
            ContentUnavailableView.search(text: vm.searchText)
        } else {
            ContentUnavailableView {
                Label("Nothing marked \(vm.tierFilter?.label ?? "")", systemImage: "sparkles")
            } description: {
                Text("No items at this safety level on your Mac right now.")
            }
        }
    }

    // MARK: Floating bar

    private var barState: Int {
        if vm.receipt != nil { return 2 }
        return vm.selectedItems.isEmpty ? 0 : 1
    }

    private var floatingBar: some View {
        ZStack {
            if let receipt = vm.receipt {
                TrashToast(
                    receipt: receipt,
                    onUndo: { withAnimation(motion(reduceMotion)) { vm.undoLastTrash() } },
                    onDismiss: { withAnimation(motion(reduceMotion)) { vm.receipt = nil } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !vm.selectedItems.isEmpty {
                SelectionBar(
                    count: vm.selectedItems.count,
                    bytes: vm.selectedBytes,
                    needsReview: vm.selectedItems.filter { $0.safety != .safe }.count,
                    onClear: { withAnimation(motion(reduceMotion)) { vm.clearSelection() } },
                    onTrash: {
                        if vm.selectedItems.contains(where: { $0.safety != .safe }) {
                            confirmTrash = true
                        } else {
                            trash()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 18)
        .padding(.horizontal, 20)
        .animation(motion(reduceMotion), value: barState)
    }

    private func trash() {
        withAnimation(motion(reduceMotion)) { vm.moveSelectedToTrash() }
    }
}

// MARK: - Overview

private struct OverviewHeader: View {
    @ObservedObject var vm: StorageViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let reclaimable = splitSize(ByteFormatter.string(vm.bytes(for: .safe)))

        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    headline(reclaimable, inline: true)
                    Spacer(minLength: 24)
                    diskSummary(alignment: .trailing)
                }
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    headline(reclaimable, inline: false)
                    Spacer(minLength: 24)
                    diskSummary(alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 10) {
                    headline(reclaimable, inline: false)
                    diskSummary(alignment: .leading)
                }
            }

            CapacityBar(
                segments: SafetyLevel.allCases.map { (color: $0.tint, bytes: vm.bytes(for: $0)) },
                total: vm.foundBytes,
                selected: vm.selectedBytes
            )
            .animation(motion(reduceMotion, .smooth(duration: 0.25)), value: vm.selectedBytes)
            .animation(motion(reduceMotion, .smooth(duration: 0.25)), value: vm.foundBytes)

            ViewThatFits(in: .horizontal) {
                legend(withSizes: true)
                legend(withSizes: false)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private func headline(_ reclaimable: (value: String, unit: String), inline: Bool) -> some View {
        let caption = Text("safe to remove, of \(ByteFormatter.string(vm.foundBytes)) found")
            .foregroundStyle(.secondary)

        return VStack(alignment: .leading, spacing: 2) {
            Text("Reclaimable")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(reclaimable.value)
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(-1)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(motion(reduceMotion), value: reclaimable.value)
                Text(reclaimable.unit)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                if inline {
                    caption.padding(.leading, 8)
                }
            }
            if !inline {
                caption
            }
        }
        .fixedSize()
    }

    private func diskSummary(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(vm.disk.totalBytes > 0 ? "\(vm.disk.formattedFree) free" : "Reading disk…")
                .fontWeight(.semibold)
                .monospacedDigit()
            if vm.disk.totalBytes > 0 {
                Text("of \(vm.disk.formattedTotal)")
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }

    private func legend(withSizes: Bool) -> some View {
        HStack(spacing: 18) {
            LegendDot(color: .accentColor, text: withSizes ? "Selected \(ByteFormatter.string(vm.selectedBytes))" : "Selected")
            ForEach(SafetyLevel.allCases, id: \.self) { level in
                LegendDot(color: level.tint.opacity(0.55),
                          text: withSizes ? "\(level.label) \(ByteFormatter.string(vm.bytes(for: level)))" : level.label)
            }
        }
        .fixedSize()
    }
}

// Selected bytes are drawn over the found-items bar, so ticking items previews what a cleanup would take.
private struct CapacityBar: View {
    let segments: [(color: Color, bytes: Int64)]
    let total: Int64
    let selected: Int64

    var body: some View {
        GeometryReader { geo in
            let scale = total > 0 ? geo.size.width / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        Rectangle()
                            .fill(segment.color.opacity(0.28))
                            .frame(width: max(0, CGFloat(segment.bytes) * scale - 2))
                    }
                }
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: CGFloat(min(selected, total)) * scale)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .accessibilityElement()
        .accessibilityLabel("\(ByteFormatter.string(selected)) selected of \(ByteFormatter.string(total)) found")
    }
}

struct LegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Pill picker

/// Segmented filter used by every mode: one pill slides between the options.
struct PillPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String, count: Int)]
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isOn = option.value == selection
                Button {
                    withAnimation(motion(reduceMotion)) { selection = option.value }
                } label: {
                    HStack(spacing: 5) {
                        Text(option.label)
                        Text("\(option.count)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .frame(minWidth: 62)
                    .frame(height: 26)
                    .background {
                        if isOn {
                            Capsule()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                                .matchedGeometryEffect(id: "pill", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .fixedSize()
    }
}

// MARK: - List

private struct ItemList: View {
    @ObservedObject var vm: StorageViewModel
    let onQuickLook: (CleanupItem) -> Void
    let onOpenDetails: () -> Void
    /// Room kept below the last row so the floating bar never covers it; only while the bar is up.
    let bottomInset: CGFloat
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.visibleItems) { item in
                        ItemRow(
                            item: item,
                            isFocused: item.id == vm.focusedID,
                            onToggle: { withAnimation(motion(reduceMotion)) { vm.toggle(item.id) } },
                            onFocus: {
                                vm.focusedID = item.id
                                isFocused = true
                                onOpenDetails()
                            },
                            onQuickLook: { onQuickLook(item) }
                        )
                        .id(item.id)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, bottomInset)
                .animation(motion(reduceMotion), value: bottomInset)
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) {
                vm.moveFocus(by: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                vm.moveFocus(by: 1)
                return .handled
            }
            .onKeyPress(.space) {
                guard let id = vm.focusedID else { return .ignored }
                withAnimation(motion(reduceMotion)) { vm.toggle(id) }
                return .handled
            }
            .onChange(of: vm.focusedID) { _, id in
                guard let id else { return }
                withAnimation(motion(reduceMotion, .smooth(duration: 0.2))) { proxy.scrollTo(id) }
            }
            .onAppear { isFocused = true }
        }
    }
}

private struct ItemRow: View {
    let item: CleanupItem
    let isFocused: Bool
    let onToggle: () -> Void
    let onFocus: () -> Void
    let onQuickLook: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            SelectionCheck(isOn: item.selected, label: item.name, action: onToggle)

            OwnerIcon(owner: item.owner, size: 26)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.owner.name)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .help("\(item.name) · \(item.owner.name)")

            Spacer(minLength: 12)

            TierTag(level: item.safety)
                .frame(width: 72, alignment: .leading)

            Text(item.formattedSize)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)

            Button {
                reveal(item)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal \(item.name) in Finder")
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(background)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onFocus)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .contextMenu {
            Button(item.selected ? "Deselect" : "Select", action: onToggle)
            Divider()
            Button("Reveal in Finder") { reveal(item) }
            Button("Quick Look", action: onQuickLook)
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
        }
    }

    private var background: Color {
        if isFocused { return Color.accentColor.opacity(0.12) }
        return isHovered ? Color.primary.opacity(0.045) : .clear
    }
}

private struct SelectionCheck: View {
    let isOn: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(isOn ? Color.accentColor : Color.secondary.opacity(0.55), lineWidth: 1.5)
                    .background(Circle().fill(isOn ? Color.accentColor : Color.clear))
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isOn ? 1 : 0)
            }
            .frame(width: 18, height: 18)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .animation(.easeOut(duration: 0.15), value: isOn)
        .accessibilityLabel("Select \(label)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct TierTag: View {
    let level: SafetyLevel

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(level.tint).frame(width: 6, height: 6)
            Text(level.label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .help(level.note)
    }
}

// The installed app's own icon when there is one; otherwise a neutral tile with the owner's SF Symbol.
private struct OwnerIcon: View {
    let owner: ItemOwner
    let size: CGFloat

    var body: some View {
        if let image = AppIcons.icon(for: owner) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay(
                    Image(systemName: owner.symbol)
                        .font(.system(size: size * 0.46, weight: .medium))
                        .foregroundStyle(.secondary)
                )
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Details

private struct DetailsPane: View {
    let item: CleanupItem?
    let foundBytes: Int64
    let onToggle: () -> Void
    let onReveal: () -> Void
    let onQuickLook: () -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            DetailsHeader(onClose: onClose)
            itemDetails
        }
    }

    private var itemDetails: some View {
        Group {
            if let item {
                VStack(spacing: 0) {
                    ScrollView {
                        details(item)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    actions(item)
                        .padding(16)
                }
                .id(item.id)
                .transition(.opacity)
            } else {
                ContentUnavailableView {
                    Label("Nothing selected", systemImage: "sidebar.right")
                } description: {
                    Text("Pick an item to see what it is and what removing it would do.")
                }
            }
        }
        .animation(motion(reduceMotion, .easeOut(duration: 0.16)), value: item?.id)
    }

    private func details(_ item: CleanupItem) -> some View {
        let size = splitSize(item.formattedSize)
        let share = foundBytes > 0 ? Double(item.bytes) / Double(foundBytes) : 0

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                OwnerIcon(owner: item.owner, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.title3.weight(.semibold))
                    Text("\(item.owner.name) · \(item.category.rawValue)")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(size.value)
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                    Text(size.unit)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(max(1, Int((share * 100).rounded())))% of found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    Capsule()
                        .fill(item.safety.tint)
                        .frame(width: max(4, geo.size.width * share))
                }
                .frame(height: 4)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
            }

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(item.safety.tint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.safety.label).fontWeight(.semibold)
                    Text(item.safety.note).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))

            section("What it is", item.whatItIs)
            section("If removed", item.whatHappensIfRemoved)

            Divider()

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Last modified").foregroundStyle(.secondary)
                    Text(item.lastModified.map { $0.formatted(.relative(presentation: .named)) } ?? "Unknown")
                }
                GridRow {
                    Text("Location").foregroundStyle(.secondary)
                    Text(item.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Source").foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: item.verified ? "checkmark.seal.fill" : "questionmark.circle")
                            .foregroundStyle(item.verified ? Color.green : Color.secondary)
                        Text(item.verified ? "Cross-referenced" : "First-draft (unverified)")
                    }
                    .help(item.verified
                        ? "Path, tier, and effect checked against a source listed in references/sources.md."
                        : "Added from memory. Behavior not yet cross-referenced against a primary source.")
                }
            }
            .font(.callout)
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
        }
    }

    private func actions(_ item: CleanupItem) -> some View {
        HStack(spacing: 8) {
            Button("Reveal", action: onReveal)
            Button("Quick Look", action: onQuickLook)
            Spacer(minLength: 0)
            if item.selected {
                Button("Selected", action: onToggle)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Select", action: onToggle)
            }
        }
        .buttonBorderShape(.capsule)
    }
}

struct DetailsHeader: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Details")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Hide details  ⌥⌘I")
                .accessibilityLabel("Hide details")
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            Divider()
        }
    }
}

// MARK: - Floating bar

private struct SelectionBar: View {
    let count: Int
    let bytes: Int64
    let needsReview: Int
    let onClear: () -> Void
    let onTrash: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text("\(count) \(count == 1 ? "item" : "items")")
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(ByteFormatter.string(bytes))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
            if needsReview > 0 {
                HStack(spacing: 5) {
                    Circle().fill(SafetyLevel.review.tint).frame(width: 6, height: 6)
                    Text("\(needsReview) to review")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Clear", action: onClear)
                .buttonStyle(.borderless)
            Button(action: onTrash) {
                Label("Move to Trash", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .fixedSize()
        .padding(.leading, 20)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .modifier(FloatingCapsule())
    }
}

private struct TrashToast: View {
    let receipt: StorageViewModel.TrashReceipt
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(receipt.failed.isEmpty ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(ByteFormatter.string(receipt.bytes)) moved to the Trash")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(receipt.failed.isEmpty
                     ? "Empty the Trash to free the space."
                     : "Couldn't move \(receipt.failed.joined(separator: ", ")).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 320, alignment: .leading)
                    .help(receipt.failed.joined(separator: ", "))
            }
            if receipt.canUndo {
                Button("Undo", action: onUndo)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut("z", modifiers: .command)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .modifier(FloatingCapsule())
        .task(id: receipt.id) {
            guard receipt.failed.isEmpty else { return }
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled { onDismiss() }
        }
    }
}

// Liquid Glass on macOS 26 when built with its SDK; the regular material everywhere else.
private struct FloatingCapsule: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            material(content)
        }
        #else
        material(content)
        #endif
    }

    private func material(_ content: Content) -> some View {
        content
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

// MARK: - States

// Permissions placeholder is retired; PermissionsView (in its own file) now
// renders the TCC-backed content, Full Disk Access onboarding, and empty states.
private typealias PermissionsPlaceholder = PermissionsView

private struct ScanningState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Inspecting \(KnownItems.catalog.count) known locations…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyState: View {
    let rescan: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Nothing hiding here", systemImage: "checkmark.seal")
        } description: {
            Text("Inspector checked \(KnownItems.catalog.count) known caches, leftovers and developer folders. None are large enough to be worth your attention.")
        } actions: {
            Button("Scan Again", action: rescan)
        }
    }
}

// MARK: - Toolbar

private struct ToolbarSearchField: View {
    @Binding var text: String
    let prompt: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused(isFocused)
                .onExitCommand {
                    text = ""
                    isFocused.wrappedValue = false
                }
            if text.isEmpty {
                Text("⌘F")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } else {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 300, height: 26)
        .modifier(SearchFieldChrome())
    }
}

/// Storage · Boot · Permissions as compact icon-and-label tabs, the way Finder and Xcode
/// title their toolbar segments. A custom control because a segmented `Picker` drops
/// either the icon or the title on macOS.
private struct ModeTabs: View {
    @Binding var selection: InspectorMode
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(InspectorMode.allCases) { mode in
                tab(mode)
            }
        }
        .modifier(ModeTabsTrack())
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View")
    }

    private func tab(_ mode: InspectorMode) -> some View {
        let isSelected = mode == selection
        return Button {
            withAnimation(motion(reduceMotion, .snappy(duration: 0.2))) { selection = mode }
        } label: {
            Label(mode.title, systemImage: mode.symbol)
                .labelStyle(.titleAndIcon)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 11)
                .frame(height: 24)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("\(mode.title)  ⌘\(String(mode.shortcut.character))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// macOS 26 already wraps the item in a glass capsule; a second track inside it
// would leave two outlines with mismatched curves at the ends.
private struct ModeTabsTrack: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
        } else {
            track(content)
        }
        #else
        track(content)
        #endif
    }

    private func track(_ content: Content) -> some View {
        content
            .padding(2)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }
}

// On macOS 26 the toolbar already draws a glass capsule around each item.
private struct SearchFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
        } else {
            field(content)
        }
        #else
        field(content)
        #endif
    }

    private func field(_ content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}

@MainActor
private func focusToolbarTextField() {
    guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
    func editableField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField, field.isEditable { return field }
        for subview in view.subviews {
            if let field = editableField(in: subview) { return field }
        }
        return nil
    }
    for item in window.toolbar?.items ?? [] {
        if let view = item.view, let field = editableField(in: view) {
            window.makeFirstResponder(field)
            return
        }
    }
}

// An invisible button that only exists to carry a keyboard shortcut.
private struct ShortcutButton: View {
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let action: () -> Void

    var body: some View {
        Button("", action: action)
            .keyboardShortcut(key, modifiers: modifiers)
            .opacity(0)
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
