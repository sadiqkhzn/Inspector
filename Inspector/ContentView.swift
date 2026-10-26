import SwiftUI
import AppKit

@MainActor
final class StorageViewModel: ObservableObject {
    @Published var items: [CleanupItem] = []
    @Published var disk = DiskSnapshot(totalBytes: 0, freeBytes: 0)
    @Published var isScanning = false
    @Published var statusMessage: String?
    @Published var safetyFilter: SafetyLevel? = nil
    @Published var categoryFilter: ScanCategory? = nil
    @Published var searchText: String = ""

    var visibleItems: [CleanupItem] {
        items.filter { item in
            (safetyFilter == nil || item.safety == safetyFilter!) &&
            (categoryFilter == nil || item.category == categoryFilter!) &&
            (searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    var selectedBytes: Int64 {
        items.filter { $0.selected }.reduce(0) { $0 + $1.bytes }
    }

    var formattedSelected: String {
        ByteFormatter.string(selectedBytes)
    }

    func refresh() async {
        isScanning = true
        statusMessage = nil
        disk = Scanner.diskSnapshot()
        items = await Scanner.scan()
        isScanning = false
    }

    func selectAllSafe() {
        for i in items.indices where items[i].safety == .safe {
            items[i].selected = true
        }
    }

    func reclaimSelected() async {
        let selected = items.filter { $0.selected }
        guard !selected.isEmpty else { return }
        var reclaimed: Int64 = 0
        var failed: [String] = []
        for item in selected {
            do {
                try Scanner.remove(item)
                reclaimed += item.bytes
            } catch {
                failed.append(item.name)
            }
        }
        await refresh()
        let freed = ByteFormatter.string(reclaimed)
        if failed.isEmpty {
            statusMessage = "Freed \(freed)."
        } else {
            statusMessage = "Freed \(freed). Could not remove: \(failed.joined(separator: ", "))."
        }
    }
}

// MARK: - Design tokens

private enum Facet: Hashable {
    case safety(SafetyLevel?)
    case category(ScanCategory?)
}

private let allCategories: [ScanCategory] = [.cache, .installerLeftover, .appData, .devTool]

private enum Palette {
    static let safe = Color(nsColor: .systemGreen)
    static let review = Color(nsColor: .systemOrange)
    // Keep is deliberately neutral: it is "shown for visibility", not a threat.
    static let keep = Color(nsColor: .systemGray)
    static let used = Color.primary.opacity(0.32)
    static let track = Color.primary.opacity(0.08)
    static let contentBackground = Color(nsColor: .textBackgroundColor)
}

private extension SafetyLevel {
    var tint: Color {
        switch self {
        case .safe:   return Palette.safe
        case .review: return Palette.review
        case .keep:   return Palette.keep
        }
    }

    var symbol: String {
        switch self {
        case .safe:   return "checkmark"
        case .review: return "eye"
        case .keep:   return "lock.fill"
        }
    }

    var shortExplanation: String {
        switch self {
        case .safe:   return "Rebuilt automatically when needed."
        case .review: return "Holds real state. Know the trade-off."
        case .keep:   return "Your data. Shown, not suggested."
        }
    }
}

private extension ScanCategory {
    var symbol: String {
        switch self {
        case .cache:             return "clock.arrow.circlepath"
        case .installerLeftover: return "shippingbox"
        case .appData:           return "square.stack.3d.up"
        case .devTool:           return "hammer"
        }
    }
}

private func splitSize(_ formatted: String) -> (value: String, unit: String) {
    guard let i = formatted.lastIndex(where: { $0.isWhitespace }) else { return (formatted, "") }
    return (String(formatted[..<i]), String(formatted[formatted.index(after: i)...]))
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var vm = StorageViewModel()
    @State private var hasScanned = false
    @State private var isConfirmingReclaim = false
    @State private var isReclaiming = false
    @State private var showResult = false
    @State private var highlightFree = false
    @State private var resultToken = 0

    var body: some View {
        NavigationSplitView {
            Sidebar(vm: vm)
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 300)
        } detail: {
            detail
                .navigationSplitViewColumnWidth(min: 480, ideal: 840)
        }
        .modifier(HiddenWindowTitle())
        .searchable(text: $vm.searchText, placement: .toolbar, prompt: "Filter by name")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await vm.refresh() }
                } label: {
                    if vm.isScanning {
                        ProgressView().controlSize(.small).frame(width: 16, height: 16)
                    } else {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
                .help("Rescan (⌘R)")
                .keyboardShortcut("r")
                .disabled(vm.isScanning || isReclaiming)
            }
        }
        .confirmationDialog(
            "Reclaim \(vm.formattedSelected)?",
            isPresented: $isConfirmingReclaim,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedItems.count) \(selectedItems.count == 1 ? "Item" : "Items")", role: .destructive) {
                performReclaim()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .task {
            await vm.refresh()
            hasScanned = true
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            Header(disk: vm.disk, selectedBytes: vm.selectedBytes, highlightFree: highlightFree)
            Divider()
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(-1)
            if showResult || (hasScanned && !vm.items.isEmpty) {
                bottomBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.contentBackground)
    }

    @ViewBuilder
    private var mainContent: some View {
        if !hasScanned || (vm.isScanning && vm.items.isEmpty) {
            ScanningState()
        } else if vm.items.isEmpty {
            EmptyState { Task { await vm.refresh() } }
        } else {
            let visible = vm.visibleItems
            VStack(spacing: 0) {
                ListHeader(vm: vm, visible: visible, clearFilters: clearFilters)
                Divider()
                if visible.isEmpty {
                    ContentUnavailableView {
                        Label("No matching items", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Nothing matches the current filters.")
                    } actions: {
                        Button("Clear Filters", action: clearFilters)
                    }
                } else {
                    ItemList(vm: vm, items: visible)
                        .opacity(vm.isScanning ? 0.5 : 1)
                        .allowsHitTesting(!vm.isScanning)
                }
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if showResult, let message = vm.statusMessage {
                    ReclaimResult(message: message, freeNow: vm.disk.formattedFree, onDismiss: dismissResult)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    actionBar
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if selectedItems.isEmpty {
                ViewThatFits(in: .horizontal) {
                    Text("Nothing selected. Items marked Safe are a good place to start.")
                    Text("Nothing selected.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("\(selectedItems.count) selected")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                        Button("Clear", action: deselectAll)
                            .buttonStyle(.link)
                            .font(.callout)
                    }
                    if let caution = cautionText {
                        Label(caution, systemImage: "eye")
                            .font(.caption)
                            .foregroundStyle(Palette.review)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 12)

            Button("Select All Safe") {
                withAnimation(.easeOut(duration: 0.15)) { vm.selectAllSafe() }
            }
            .controlSize(.large)
            .fixedSize()
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(!vm.items.contains { $0.safety == .safe && !$0.selected })

            Button {
                isConfirmingReclaim = true
            } label: {
                HStack(spacing: 6) {
                    if isReclaiming {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(vm.selectedBytes > 0 ? "Reclaim \(vm.formattedSelected)" : "Reclaim")
                        .monospacedDigit()
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .fixedSize()
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(vm.selectedBytes == 0 || isReclaiming || vm.isScanning)
        }
    }

    // MARK: Derived state

    private var selectedItems: [CleanupItem] {
        vm.items.filter(\.selected)
    }

    private var cautionText: String? {
        let review = selectedItems.filter { $0.safety == .review }.count
        let keep = selectedItems.filter { $0.safety == .keep }.count
        var parts: [String] = []
        if review > 0 { parts.append("\(review) Review \(review == 1 ? "item" : "items")") }
        if keep > 0 { parts.append("\(keep) Keep \(keep == 1 ? "item" : "items")") }
        guard !parts.isEmpty else { return nil }
        return "Includes " + parts.joined(separator: " and ")
    }

    private var confirmationMessage: String {
        let count = selectedItems.count
        var message = "\(count) \(count == 1 ? "item" : "items") will be permanently deleted. They are not moved to the Trash."
        if cautionText != nil {
            message += " Your selection includes items marked Review or Keep."
        }
        return message
    }

    // MARK: Actions

    @MainActor
    private func performReclaim() {
        isReclaiming = true
        resultToken += 1
        let token = resultToken
        Task { @MainActor in
            await vm.reclaimSelected()
            isReclaiming = false
            guard let message = vm.statusMessage else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                showResult = true
                highlightFree = true
            }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.25)) { highlightFree = false }

            guard !message.contains("Could not remove") else { return }
            try? await Task.sleep(for: .seconds(6))
            if token == resultToken, showResult { dismissResult() }
        }
    }

    @MainActor
    private func dismissResult() {
        withAnimation(.easeOut(duration: 0.2)) { showResult = false }
        vm.statusMessage = nil
    }

    @MainActor
    private func deselectAll() {
        withAnimation(.easeOut(duration: 0.15)) {
            for i in vm.items.indices { vm.items[i].selected = false }
        }
    }

    @MainActor
    private func clearFilters() {
        vm.safetyFilter = nil
        vm.categoryFilter = nil
        vm.searchText = ""
    }
}

// `.toolbar(removing: .title)` is macOS 15+; the in-content header carries the brand instead.
private struct HiddenWindowTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .navigationTitle("Inspector")
                .toolbar(removing: .title)
        } else {
            content.navigationTitle("Inspector")
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @ObservedObject var vm: StorageViewModel

    var body: some View {
        VStack(spacing: 0) {
            facetList
                .layoutPriority(-1)
            Divider()
            TierLegend()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var facetList: some View {
        List(selection: selection) {
            Section("Safety") {
                row(.safety(nil), title: "All Items", symbol: "tray.full", tint: .secondary, items: vm.items)
                ForEach(SafetyLevel.allCases, id: \.self) { level in
                    row(.safety(level), title: level.label, symbol: level.symbol, tint: level.tint,
                        items: vm.items.filter { $0.safety == level })
                        .help(level.shortExplanation)
                }
            }
            Section("Category") {
                row(.category(nil), title: "All Categories", symbol: "square.grid.2x2", tint: .secondary, items: vm.items)
                ForEach(allCategories, id: \.self) { category in
                    row(.category(category), title: category.rawValue, symbol: category.symbol, tint: .secondary,
                        items: vm.items.filter { $0.category == category })
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ facet: Facet, title: String, symbol: String, tint: Color, items: [CleanupItem]) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .badge(items.count)
        .tag(facet)
    }

    // The sidebar shows one active row per section, so a multi-selection List is used as
    // two independent radio groups: each click replaces only the facet in its own section.
    private var selection: Binding<Set<Facet>> {
        Binding(
            get: { [.safety(vm.safetyFilter), .category(vm.categoryFilter)] },
            set: { newValue in
                let current: Set<Facet> = [.safety(vm.safetyFilter), .category(vm.categoryFilter)]
                let added = newValue.subtracting(current)
                guard added.count == 1, let facet = added.first else {
                    DispatchQueue.main.async { vm.objectWillChange.send() }
                    return
                }
                switch facet {
                case .safety(let level):       vm.safetyFilter = level
                case .category(let category):  vm.categoryFilter = category
                }
            }
        )
    }
}

private struct TierLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(SafetyLevel.allCases, id: \.self) { level in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: level.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(level.tint)
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(level.label).font(.caption.weight(.semibold))
                        Text(level.shortExplanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Header

private struct Header: View {
    let disk: DiskSnapshot
    let selectedBytes: Int64
    let highlightFree: Bool

    private var hasDisk: Bool { disk.totalBytes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    brand
                    Spacer(minLength: 24)
                    diskSummary(alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 12) {
                    brand
                    diskSummary(alignment: .leading)
                }
            }

            CapacityBar(disk: disk, selectedBytes: selectedBytes)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .animation(.easeOut(duration: 0.25), value: disk.freeBytes)
    }

    private var brand: some View {
        HStack(spacing: 12) {
            BrandMark()
            VStack(alignment: .leading, spacing: 1) {
                Text("Inspector")
                    .font(.system(size: 20, weight: .semibold))
                Text("See what macOS hides.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
        }
    }

    private func diskSummary(alignment: HorizontalAlignment) -> some View {
        let free = splitSize(disk.formattedFree)
        return VStack(alignment: alignment, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(hasDisk ? free.value : "—")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(highlightFree ? Palette.safe : Color.primary)
                Text(hasDisk ? "\(free.unit) free" : "free")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(hasDisk ? "\(disk.formattedUsed) of \(disk.formattedTotal) used" : "Reading disk…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .fixedSize()
    }
}

private struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                    startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            Image(systemName: "viewfinder")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
        .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}

// Selected bytes are carved out of the used segment so the bar previews the result of a reclaim.
private struct CapacityBar: View {
    let disk: DiskSnapshot
    let selectedBytes: Int64

    var body: some View {
        let total = max(Double(disk.totalBytes), 1)
        let used = Double(max(disk.usedBytes, 0)) / total
        let selected = Double(min(selectedBytes, max(disk.usedBytes, 0))) / total

        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Palette.track)
                    Rectangle()
                        .fill(Palette.used)
                        .frame(width: geo.size.width * used)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * selected)
                        .offset(x: geo.size.width * (used - selected))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack(spacing: 14) {
                LegendDot(color: Palette.used, text: "Used \(Int(disk.usedPercent.rounded()))%")
                if selectedBytes > 0 {
                    LegendDot(color: .accentColor, text: "Selected \(ByteFormatter.string(selectedBytes))")
                        .transition(.opacity)
                }
                LegendDot(color: Palette.track, text: "Free")
            }
        }
        .animation(.easeOut(duration: 0.25), value: selectedBytes)
        .animation(.easeOut(duration: 0.25), value: disk.freeBytes)
    }
}

private struct LegendDot: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - List

private struct ListHeader: View {
    @ObservedObject var vm: StorageViewModel
    let visible: [CleanupItem]
    let clearFilters: () -> Void

    private var isFiltered: Bool {
        vm.safetyFilter != nil || vm.categoryFilter != nil || !vm.searchText.isEmpty
    }

    private var scopeTitle: String {
        var parts: [String] = []
        if let level = vm.safetyFilter { parts.append(level.label) }
        if let category = vm.categoryFilter { parts.append(category.rawValue) }
        return parts.isEmpty ? "All items" : parts.joined(separator: " · ")
    }

    var body: some View {
        let total = visible.reduce(Int64(0)) { $0 + $1.bytes }

        HStack(spacing: 10) {
            Text(scopeTitle).font(.headline).lineLimit(1)
            Text("\(visible.count) \(visible.count == 1 ? "item" : "items") · \(ByteFormatter.string(total))")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
            if isFiltered {
                Button(action: clearFilters) {
                    Label("Clear filters", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .help("Clear filters")
            }
            if vm.isScanning {
                ProgressView().controlSize(.small)
                Text("Rescanning…").font(.caption).foregroundStyle(.secondary).fixedSize()
            }

            Spacer(minLength: 12)

            ViewThatFits(in: .horizontal) {
                Label("Safety, then size", systemImage: "arrow.down")
                Image(systemName: "arrow.down")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .help("Sorted by safety tier (Safe first), then largest first.")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

private struct ItemList: View {
    @ObservedObject var vm: StorageViewModel
    let items: [CleanupItem]

    var body: some View {
        let maxBytes = max(items.map(\.bytes).max() ?? 1, 1)

        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ItemRow(
                        item: item,
                        isSelected: selectionBinding(for: item),
                        sizeFraction: Double(item.bytes) / Double(maxBytes)
                    )
                    if item.id != items.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }

    // Bound by id rather than index so a rescan replacing `items` can't leave a stale index behind.
    private func selectionBinding(for item: CleanupItem) -> Binding<Bool> {
        Binding(
            get: { vm.items.first { $0.id == item.id }?.selected ?? false },
            set: { newValue in
                if let i = vm.items.firstIndex(where: { $0.id == item.id }) {
                    vm.items[i].selected = newValue
                }
            }
        )
    }
}

private struct ItemRow: View {
    let item: CleanupItem
    @Binding var isSelected: Bool
    let sizeFraction: Double
    @State private var isHovered = false

    private var fileURL: URL {
        URL(fileURLWithPath: (item.path as NSString).expandingTildeInPath)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Toggle("Select \(item.name)", isOn: $isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 5) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        title
                        SafetyBadge(level: item.safety)
                        CategoryTag(category: item.category)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            title
                            SafetyBadge(level: item.safety)
                        }
                        CategoryTag(category: item.category)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.body.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            SafetyBadge(level: item.safety)
                            CategoryTag(category: item.category)
                        }
                    }
                }

                Text(item.whatItIs)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Text("\(Text("If removed:").fontWeight(.medium)) \(item.whatHappensIfRemoved)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(item.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }

            Spacer(minLength: 16)

            SizeColumn(formatted: item.formattedSize, fraction: sizeFraction, tint: item.safety.tint)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2)
                .opacity(isSelected ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { isSelected.toggle() }
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .contextMenu {
            Button(isSelected ? "Deselect" : "Select") { isSelected.toggle() }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fileURL.path, forType: .string)
            }
        }
    }

    private var title: some View {
        Text(item.name)
            .font(.body.weight(.semibold))
            .fixedSize()
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(isHovered ? 0.11 : 0.08) }
        return isHovered ? Color.primary.opacity(0.035) : .clear
    }
}

private struct SizeColumn: View {
    let formatted: String
    let fraction: Double
    let tint: Color

    var body: some View {
        let size = splitSize(formatted)

        VStack(alignment: .trailing, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(size.value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(size.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    Capsule().fill(Palette.track)
                    Capsule()
                        .fill(tint.opacity(0.75))
                        .frame(width: max(3, geo.size.width * fraction))
                }
            }
            .frame(width: 64, height: 3)
        }
        .frame(width: 104, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(formatted)
    }
}

private struct SafetyBadge: View {
    let level: SafetyLevel

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: level.symbol)
                .font(.system(size: 8, weight: .bold))
            Text(level.label.uppercased())
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.4)
        }
        .foregroundStyle(level.tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .fixedSize()
        .background(level.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(level.tint.opacity(0.28), lineWidth: 0.5)
        )
        .help(level.shortExplanation)
    }
}

private struct CategoryTag: View {
    let category: ScanCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.symbol)
                .font(.system(size: 10))
            Text(category.rawValue)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

// MARK: - States

private struct ScanningState: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Inspecting \(KnownItems.catalog.count) known locations…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct EmptyState: View {
    let rescan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Palette.safe.opacity(0.12))
                    .frame(width: 84, height: 84)
                Circle()
                    .strokeBorder(Palette.safe.opacity(0.2), lineWidth: 1)
                    .frame(width: 84, height: 84)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Palette.safe)
            }
            VStack(spacing: 6) {
                Text("Nothing hiding here")
                    .font(.title3.weight(.semibold))
                Text("Inspector checked \(KnownItems.catalog.count) known caches, installer leftovers, and developer tool folders. None are large enough to be worth your attention.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            Button("Scan Again", action: rescan)
                .controlSize(.large)
        }
        .padding(32)
    }
}

private struct ReclaimResult: View {
    let message: String
    let freeNow: String
    let onDismiss: () -> Void

    // Splits the view model's "Freed X. Could not remove: …" into a headline and a detail line.
    private var parsed: (headline: String, failures: String?) {
        let prefix = "Freed "
        guard message.hasPrefix(prefix) else { return (message, nil) }
        let rest = message.dropFirst(prefix.count)
        if let r = rest.range(of: ". ") {
            return ("Freed \(rest[..<r.lowerBound])", String(rest[r.upperBound...]))
        }
        return ("Freed \(rest.hasSuffix(".") ? rest.dropLast() : rest)", nil)
    }

    var body: some View {
        let result = parsed
        let tint = result.failures == nil ? Palette.safe : Palette.review

        HStack(spacing: 12) {
            Image(systemName: result.failures == nil ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.headline)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Free space is now \(freeNow).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let failures = result.failures {
                    Text(failures)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 12)
            Button("Done", action: onDismiss)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
        }
        .accessibilityElement(children: .combine)
    }
}
