import SwiftUI
import AppKit

@MainActor
final class BootViewModel: ObservableObject {
    enum StatusFilter: Hashable {
        case all, enabled, disabled
    }

    @Published private(set) var items: [BootItem] = []
    @Published private(set) var hasLoaded = false
    @Published var searchText: String = ""
    @Published var filter: StatusFilter = .all
    @Published var focusedID: BootItem.ID?

    var visibleItems: [BootItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            matches(item, filter) && (query.isEmpty || item.searchableText.localizedCaseInsensitiveContains(query))
        }
    }

    var enabledCount: Int { items.filter(\.enabled).count }
    var focusedItem: BootItem? { items.first { $0.id == focusedID } }

    func count(for filter: StatusFilter) -> Int { items.filter { matches($0, filter) }.count }

    func load() {
        items = BootScanner.scan()
        if focusedItem == nil { focusedID = visibleItems.first?.id }
        hasLoaded = true
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

    private func matches(_ item: BootItem, _ filter: StatusFilter) -> Bool {
        switch filter {
        case .all:      return true
        case .enabled:  return item.enabled
        case .disabled: return item.disabled
        }
    }
}

// MARK: - Presentation

private extension BootItem {
    var statusTint: Color { enabled ? Color(nsColor: .systemGreen) : Color(nsColor: .systemGray) }
    var statusLabel: String { enabled ? "Enabled" : "Disabled" }

    /// When launchd starts it, in plain English.
    var trigger: String {
        if disabled { return "Off" }
        if keepAlive { return "Always on" }
        if runAtLoad { return "At login" }
        return "On demand"
    }

    var statusNote: String {
        if disabled { return "Turned off in its plist (Disabled = true). launchd won't start it." }
        if keepAlive { return "Starts with your session, and launchd restarts it whenever it quits." }
        if runAtLoad { return "Starts automatically when you log in." }
        return "Registered with launchd, but only starts when something asks for it."
    }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = plistURL.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

private func revealPlist(_ item: BootItem) {
    NSWorkspace.shared.activateFileViewerSelecting([item.plistURL])
}

// MARK: - Content panel

struct BootContent: View {
    @ObservedObject var vm: BootViewModel
    let onOpenDetails: () -> Void
    let onQuickLook: (BootItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if !vm.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty {
                ContentUnavailableView {
                    Label("Nothing starts at login", systemImage: "bolt.horizontal.circle")
                } description: {
                    Text("There are no agents in ~/Library/LaunchAgents. System-wide agents and daemons need admin access and come in a later release.")
                }
            } else {
                BootHeader(vm: vm)
                filterBar
                if vm.visibleItems.isEmpty {
                    noMatches
                } else {
                    BootList(vm: vm, onOpenDetails: onOpenDetails, onQuickLook: onQuickLook)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            PillPicker(
                selection: $vm.filter,
                options: [
                    (value: .all, label: "All", count: vm.count(for: .all)),
                    (value: .enabled, label: "Enabled", count: vm.count(for: .enabled)),
                    (value: .disabled, label: "Disabled", count: vm.count(for: .disabled)),
                ]
            )
            Spacer(minLength: 12)
            ViewThatFits(in: .horizontal) {
                Text("Enabled first, then by app")
                Text("")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
                Label(vm.filter == .enabled ? "Nothing enabled" : "Nothing disabled", systemImage: "sparkles")
            } description: {
                Text("No agents in this group right now.")
            }
        }
    }
}

// MARK: - Header

private struct BootHeader: View {
    @ObservedObject var vm: BootViewModel

    var body: some View {
        let total = vm.items.count
        let enabled = vm.enabledCount

        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    headline(enabled: enabled, total: total, inline: true)
                    Spacer(minLength: 24)
                    location(alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 10) {
                    headline(enabled: enabled, total: total, inline: false)
                    location(alignment: .leading)
                }
            }

            GeometryReader { geo in
                Capsule()
                    .fill(Color(nsColor: .systemGreen).opacity(0.55))
                    .frame(width: total > 0 ? geo.size.width * CGFloat(enabled) / CGFloat(total) : 0)
            }
            .frame(height: 6)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel("\(enabled) of \(total) agents enabled")

            HStack(spacing: 18) {
                LegendDot(color: Color(nsColor: .systemGreen).opacity(0.75), text: "Enabled \(enabled)")
                LegendDot(color: Color.primary.opacity(0.25), text: "Disabled \(total - enabled)")
            }
            .fixedSize()
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }

    private func headline(enabled: Int, total: Int, inline: Bool) -> some View {
        let caption = Text("enabled, of \(total) in your LaunchAgents folder")
            .foregroundStyle(.secondary)

        return VStack(alignment: .leading, spacing: 2) {
            Text("Starts with your Mac")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(enabled)")
                    .font(.system(size: 44, weight: .semibold))
                    .tracking(-1)
                    .monospacedDigit()
                Text(enabled == 1 ? "agent" : "agents")
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

    private func location(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("~/Library/LaunchAgents")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
            Text("Your user agents · read-only")
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

// MARK: - List

private struct BootList: View {
    @ObservedObject var vm: BootViewModel
    let onOpenDetails: () -> Void
    let onQuickLook: (BootItem) -> Void
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.visibleItems) { item in
                        BootRow(
                            item: item,
                            isFocused: item.id == vm.focusedID,
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
                .padding(.bottom, 12)
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
            .onChange(of: vm.focusedID) { _, id in
                guard let id else { return }
                withAnimation(motion(reduceMotion, .smooth(duration: 0.2))) { proxy.scrollTo(id) }
            }
            .onAppear { isFocused = true }
        }
    }
}

private struct BootRow: View {
    let item: BootItem
    let isFocused: Bool
    let onFocus: () -> Void
    let onQuickLook: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            BootIcon(size: 26)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.owner)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .help("\(item.owner) · \(item.label)")

            Spacer(minLength: 12)

            StatusTag(item: item)
                .frame(width: 80, alignment: .leading)

            Text(item.trigger)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)

            Button {
                revealPlist(item)
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("Reveal plist in Finder")
            .accessibilityLabel("Reveal \(item.label) plist in Finder")
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
            Button("Reveal plist in Finder") { revealPlist(item) }
            Button("Quick Look", action: onQuickLook)
            Divider()
            Button("Copy Label") { copy(item.label) }
            Button("Copy Plist Path") { copy(item.plistURL.path) }
        }
    }

    private var background: Color {
        if isFocused { return Color.accentColor.opacity(0.12) }
        return isHovered ? Color.primary.opacity(0.045) : .clear
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

private struct StatusTag: View {
    let item: BootItem

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(item.statusTint).frame(width: 6, height: 6)
            Text(item.statusLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .help(item.statusNote)
    }
}

private struct BootIcon: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Color.primary.opacity(0.07))
            .overlay(
                Image(systemName: "bolt.horizontal")
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(.secondary)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Details

struct BootDetailsPane: View {
    let item: BootItem?
    let onQuickLook: () -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            DetailsHeader(onClose: onClose)
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
                        Text("Pick an agent to see what it runs and when it starts.")
                    }
                }
            }
            .animation(motion(reduceMotion, .easeOut(duration: 0.16)), value: item?.id)
        }
    }

    private func details(_ item: BootItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                BootIcon(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.owner)
                        .font(.title3.weight(.semibold))
                    Text(item.label)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(item.statusTint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.statusLabel) · \(item.trigger)").fontWeight(.semibold)
                    Text(item.statusNote).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Program")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.programDisplay)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }

            Divider()

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Run at load").foregroundStyle(.secondary)
                    Text(item.runAtLoad ? "Yes" : "No")
                }
                GridRow {
                    Text("Keep alive").foregroundStyle(.secondary)
                    Text(item.keepAlive ? "Yes" : "No")
                }
                GridRow {
                    Text("Disabled").foregroundStyle(.secondary)
                    Text(item.disabled ? "Yes" : "No")
                }
                GridRow {
                    Text("Plist").foregroundStyle(.secondary)
                    Text(item.displayPath)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .font(.callout)

            Text("Inspector only reads this file. It never edits, loads or unloads agents.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func actions(_ item: BootItem) -> some View {
        HStack(spacing: 8) {
            Button("Reveal plist in Finder") { revealPlist(item) }
            Button("Quick Look", action: onQuickLook)
            Spacer(minLength: 0)
        }
        .buttonBorderShape(.capsule)
    }
}
