import SwiftUI
import AppKit

/// Content panel for the Permissions tab. Reads TCC.db and shows who can do
/// what, either one row per app (default) or grouped by permission. Shows a
/// dedicated onboarding state when Full Disk Access hasn't been granted so
/// neither database is readable.
struct PermissionsView: View {
    @ObservedObject var vm: PermissionsViewModel
    var onOpenDetails: () -> Void = {}

    var body: some View {
        Group {
            if !vm.hasScanned {
                scanning
            } else if !vm.hasFullDiskAccess {
                fullDiskAccessNeeded
            } else if vm.items.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .task { await vm.load() }
    }

    private var scanning: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading the privacy database…")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fullDiskAccessNeeded: some View {
        ContentUnavailableView {
            Label("Grant Full Disk Access", systemImage: "lock.shield")
        } description: {
            Text("Inspector needs Full Disk Access to read macOS's privacy database and show which apps have camera, mic, screen recording and other permissions. After granting it, Inspector will pick up the change on its own.")
        } actions: {
            Button("Open System Settings → Privacy & Security") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            // No "Try again" button needed — poll the TCC DB every 2 seconds
            // while we're in the "needs FDA" state. The moment the user grants
            // access, the next tick picks it up and swaps the view.
            if !vm.hasFullDiskAccess { Task { await vm.load() } }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No permissions found",
            systemImage: "hand.raised",
            description: Text("The privacy database opened but has no entries. Grant any app a permission and rescan.")
        )
    }

    private var content: some View {
        VStack(spacing: 0) {
            PermissionsHeader(vm: vm)
            controls
            if vm.apps.isEmpty {
                noMatches
            } else {
                PermissionsList(vm: vm, onOpenDetails: onOpenDetails)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            PillPicker(
                selection: $vm.filter,
                options: PermissionsViewModel.Filter.allCases.map {
                    (value: $0, label: $0.label, count: vm.count(for: $0))
                }
            )
            Spacer(minLength: 12)
            Picker("Group", selection: $vm.grouping) {
                Text("By App").tag(PermissionsViewModel.Grouping.app)
                Text("By Permission").tag(PermissionsViewModel.Grouping.service)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
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
                Label("Nothing here", systemImage: "sparkles")
            } description: {
                Text("No permissions match this filter.")
            }
        }
    }
}

// MARK: - Header

private struct PermissionsHeader: View {
    @ObservedObject var vm: PermissionsViewModel

    var body: some View {
        let sensitive = vm.items.filter { $0.allowed && $0.service.isSensitive }.count
        let everyday = vm.items.filter { $0.allowed && !$0.service.isSensitive }.count
        let denied = vm.items.filter { !$0.allowed }.count
        let total = max(sensitive + everyday + denied, 1)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apps with access")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(vm.appsWithAccessCount)")
                        .font(.system(size: 44, weight: .semibold))
                        .tracking(-1)
                        .monospacedDigit()
                    Text(vm.appsWithAccessCount == 1 ? "app" : "apps")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("holding \(sensitive) sensitive and \(everyday) everyday permissions")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 8)
                        .layoutPriority(-1)
                }
            }

            GeometryReader { geo in
                let width = geo.size.width - 4
                HStack(spacing: 2) {
                    Capsule().fill(PermissionTone.sensitive.opacity(0.75))
                        .frame(width: width * CGFloat(sensitive) / CGFloat(total))
                    Capsule().fill(PermissionTone.allowed.opacity(0.6))
                        .frame(width: width * CGFloat(everyday) / CGFloat(total))
                    Capsule().fill(Color.primary.opacity(0.15))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel("\(sensitive) sensitive, \(everyday) everyday and \(denied) denied permissions")

            HStack(spacing: 18) {
                LegendDot(color: PermissionTone.sensitive, text: "Sensitive \(sensitive)")
                    .help("Full Disk Access, Accessibility, Input Monitoring, Screen Recording and Automation: they reach beyond the app itself.")
                LegendDot(color: PermissionTone.allowed, text: "Everyday \(everyday)")
                LegendDot(color: Color.primary.opacity(0.3), text: "Denied \(denied)")
            }
            .fixedSize()
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
    }
}

enum PermissionTone {
    static let sensitive = Color(nsColor: .systemIndigo)
    static let allowed = Color(nsColor: .systemGreen)
}

// MARK: - List

private struct PermissionsList: View {
    @ObservedObject var vm: PermissionsViewModel
    let onOpenDetails: () -> Void
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    switch vm.grouping {
                    case .app:
                        ForEach(vm.apps) { app in
                            AppRow(app: app, isFocused: vm.focusedApp == app.id) { focus(app.id) }
                                .id(app.id)
                        }
                    case .service:
                        ForEach(vm.sections) { section in
                            ServiceHeader(service: section.service, count: section.items.count)
                                .padding(.top, section.id == vm.sections.first?.id ? 4 : 14)
                            ForEach(section.items) { item in
                                ServiceRow(item: item, isFocused: vm.focusedApp == item.bundleID) { focus(item.bundleID) }
                                    .id(item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .focusable()
            .focused($isFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow)   { vm.moveFocus(by: -1); return .handled }
            .onKeyPress(.downArrow) { vm.moveFocus(by: 1); return .handled }
            .onChange(of: vm.focusedApp) { _, id in
                guard let id, vm.grouping == .app else { return }
                withAnimation(motion(reduceMotion, .smooth(duration: 0.2))) { proxy.scrollTo(id) }
            }
            .onAppear { isFocused = true }
        }
    }

    private func focus(_ app: PermissionApp.ID) {
        vm.focusedApp = app
        isFocused = true
        onOpenDetails()
    }
}

/// One app, with the permissions it holds as a quiet strip of the same glyphs
/// System Settings uses. Names live in tooltips and VoiceOver, not on the row.
private struct AppRow: View {
    let app: PermissionApp
    let isFocused: Bool
    let onFocus: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            PermissionAppIcon(client: app.id, size: 26)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(app.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(app.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            GlyphStrip(items: app.items)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isFocused ? Color.accentColor.opacity(0.12) : isHovered ? Color.primary.opacity(0.045) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onFocus)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(app.accessibilityList)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct GlyphStrip: View {
    let items: [PermissionItem]
    private let limit = 6

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items.prefix(limit)) { item in
                Image(systemName: item.service.symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tint(item))
                    .frame(width: 16, height: 16)
                    .help("\(item.service.displayName) · \(item.allowed ? "allowed" : "denied")")
            }
            if items.count > limit {
                Text("+\(items.count - limit)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .fixedSize()
    }

    private func tint(_ item: PermissionItem) -> Color {
        guard item.allowed else { return Color.primary.opacity(0.22) }
        return item.service.isSensitive ? PermissionTone.sensitive : Color.secondary
    }
}

private struct ServiceHeader: View {
    let service: PermissionService
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            ServiceTile(service: service, size: 22)
            Text(service.displayName)
                .fontWeight(.semibold)
            Text("\(count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if service.isSensitive {
                Text("Sensitive")
                    .font(.caption)
                    .foregroundStyle(PermissionTone.sensitive)
            }
            Spacer()
            if let url = service.settingsURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Open \(service.displayName) in System Settings")
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }
}

private struct ServiceRow: View {
    let item: PermissionItem
    let isFocused: Bool
    let onFocus: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            PermissionAppIcon(client: item.bundleID, size: 22)
            Text(item.appName)
                .lineLimit(1)
            Spacer(minLength: 12)
            if let last = item.lastModified {
                ViewThatFits(in: .horizontal) {
                    Text(last, format: .relative(presentation: .named))
                    EmptyView()
                }
                .font(.callout)
                .foregroundStyle(.tertiary)
                .help("When this permission last changed. macOS doesn't record when it was used.")
            }
            AccessState(allowed: item.allowed)
                .frame(width: 78, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.leading, 32)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isFocused ? Color.accentColor.opacity(0.12) : isHovered ? Color.primary.opacity(0.045) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onFocus)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct AccessState: View {
    let allowed: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(allowed ? PermissionTone.allowed : Color.primary.opacity(0.25))
                .frame(width: 6, height: 6)
            Text(allowed ? "Allowed" : "Denied")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

/// A Settings-style squircle: the service's glyph in white on its own colour.
struct ServiceTile: View {
    let service: PermissionService
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(service.tileColor.gradient)
            .overlay(
                Image(systemName: service.symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

extension PermissionService {
    var tileColor: Color {
        switch self {
        case .camera:           return Color(nsColor: .systemGreen)
        case .microphone:       return Color(nsColor: .systemOrange)
        case .screenRecording:  return Color(nsColor: .systemPurple)
        case .accessibility:    return Color(nsColor: .systemBlue)
        case .location:         return Color(nsColor: .systemBlue)
        case .fullDiskAccess:   return Color(nsColor: .systemGray)
        case .automation:       return Color(nsColor: .systemGray)
        case .inputMonitoring:  return Color(nsColor: .systemGray)
        case .contacts:         return Color(nsColor: .systemBrown)
        case .calendar:         return Color(nsColor: .systemRed)
        case .photos:           return Color(nsColor: .systemPink)
        case .reminders:        return Color(nsColor: .systemTeal)
        }
    }
}

// MARK: - App icons

/// The installed app's real icon for a TCC client (bundle ID or path), from
/// NSWorkspace. Falls back to a neutral tile when the app isn't on this Mac.
struct PermissionAppIcon: View {
    let client: String
    let size: CGFloat

    var body: some View {
        if let image = AppIconCache.icon(forClient: client) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay(
                    Image(systemName: client.hasPrefix("/") ? "terminal.fill" : "app.dashed")
                        .font(.system(size: size * 0.46, weight: .medium))
                        .foregroundStyle(.secondary)
                )
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()
    /// Stored for clients with no icon, so a miss isn't looked up again on every redraw.
    private static let none = NSImage()

    static func icon(forClient client: String) -> NSImage? {
        if let hit = cache.object(forKey: client as NSString) { return hit === none ? nil : hit }
        let image = resolve(client)
        cache.setObject(image ?? none, forKey: client as NSString)
        return image
    }

    private static func resolve(_ client: String) -> NSImage? {
        if client.hasPrefix("/") {
            let url = URL(fileURLWithPath: client)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            if let app = url.pathComponents.lastIndex(where: { $0.hasSuffix(".app") }) {
                return NSWorkspace.shared.icon(forFile: NSString.path(withComponents: Array(url.pathComponents[...app])))
            }
            return nil
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: client) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Model

/// Every permission one client holds, gathered for the By App view and the details pane.
struct PermissionApp: Identifiable, Hashable {
    let id: String              // TCC client: bundle ID or path
    let name: String
    let items: [PermissionItem] // allowed first, sensitive first, then by name

    var allowedCount: Int { items.filter(\.allowed).count }
    var deniedCount: Int { items.count - allowedCount }

    /// macOS copies Chrome to a temp folder while it updates, and TCC keeps the copy's path.
    var isTemporaryCopy: Bool { id.contains("code_sign_clone") }

    var summary: String {
        switch (allowedCount, deniedCount) {
        case (0, let denied): return "\(denied) denied"
        case (let allowed, 0): return "\(allowed) allowed"
        case let (allowed, denied): return "\(allowed) allowed · \(denied) denied"
        }
    }

    var accessibilityList: String {
        items.map { "\($0.service.displayName) \($0.allowed ? "allowed" : "denied")" }.joined(separator: ", ")
    }

    init(id: String, items: [PermissionItem]) {
        self.id = id
        self.name = items.first?.appName ?? id
        self.items = items.sorted { lhs, rhs in
            if lhs.allowed != rhs.allowed { return lhs.allowed }
            if lhs.service.isSensitive != rhs.service.isSensitive { return lhs.service.isSensitive }
            return lhs.service.displayName < rhs.service.displayName
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: PermissionApp, b: PermissionApp) -> Bool { a.id == b.id && a.items.map(\.id) == b.items.map(\.id) }
}

@MainActor
final class PermissionsViewModel: ObservableObject {
    enum Grouping: Hashable { case app, service }

    enum Filter: CaseIterable, Hashable {
        case all, sensitive, allowed, denied

        var label: String {
            switch self {
            case .all:       return "All"
            case .sensitive: return "Sensitive"
            case .allowed:   return "Allowed"
            case .denied:    return "Denied"
            }
        }

        func matches(_ item: PermissionItem) -> Bool {
            switch self {
            case .all:       return true
            case .sensitive: return item.service.isSensitive
            case .allowed:   return item.allowed
            case .denied:    return !item.allowed
            }
        }
    }

    @Published private(set) var items: [PermissionItem] = []
    @Published private(set) var hasFullDiskAccess = false
    @Published private(set) var hasScanned = false
    @Published var searchText: String = "" { didSet { keepFocusVisible() } }
    @Published var filter: Filter = .all { didSet { keepFocusVisible() } }
    @Published var grouping: Grouping = .app
    /// The TCC client whose permissions the details pane shows.
    @Published var focusedApp: PermissionApp.ID?

    var focused: PermissionApp? {
        guard let focusedApp else { return nil }
        let mine = items.filter { $0.bundleID == focusedApp }
        return mine.isEmpty ? nil : PermissionApp(id: focusedApp, items: mine)
    }

    var appsWithAccessCount: Int { Set(items.filter(\.allowed).map(\.bundleID)).count }

    func count(for filter: Filter) -> Int { items.filter(filter.matches).count }

    private var filtered: [PermissionItem] {
        let needle = searchText.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            filter.matches(item) && (needle.isEmpty
                || item.appName.localizedCaseInsensitiveContains(needle)
                || item.bundleID.localizedCaseInsensitiveContains(needle)
                || item.service.displayName.localizedCaseInsensitiveContains(needle))
        }
    }

    /// Apps holding anything sensitive first, then by how much they hold, then by name.
    var apps: [PermissionApp] {
        Dictionary(grouping: filtered, by: \.bundleID)
            .map { PermissionApp(id: $0.key, items: $0.value) }
            .sorted { lhs, rhs in
                let ls = lhs.items.contains { $0.allowed && $0.service.isSensitive }
                let rs = rhs.items.contains { $0.allowed && $0.service.isSensitive }
                if ls != rs { return ls }
                if lhs.allowedCount != rhs.allowedCount { return lhs.allowedCount > rhs.allowedCount }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var sections: [PermissionsSection] {
        let grouped = Dictionary(grouping: filtered, by: \.service)
        return PermissionService.allCases.compactMap { service in
            guard let items = grouped[service], !items.isEmpty else { return nil }
            return PermissionsSection(
                service: service,
                items: items.sorted { lhs, rhs in
                    if lhs.allowed != rhs.allowed { return lhs.allowed && !rhs.allowed }
                    return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
                }
            )
        }
    }

    /// Up/down walk apps in By App, and rows (by their app) in By Permission.
    func moveFocus(by offset: Int) {
        let ids: [PermissionApp.ID]
        switch grouping {
        case .app:     ids = apps.map(\.id)
        case .service: ids = sections.flatMap(\.items).map(\.bundleID)
        }
        guard !ids.isEmpty else { return }
        guard let current = focusedApp, let index = ids.firstIndex(of: current) else {
            focusedApp = ids.first
            return
        }
        focusedApp = ids[min(max(index + offset, 0), ids.count - 1)]
    }

    private func keepFocusVisible() {
        let visible = Set(filtered.map(\.bundleID))
        if let focusedApp, !visible.contains(focusedApp) { self.focusedApp = apps.first?.id }
    }

    func load() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["INSPECTOR_DEMO"] != nil {
            items = Self.demoItems
            hasFullDiskAccess = true
            hasScanned = true
            if focusedApp == nil { focusedApp = apps.first?.id }
            return
        }
        #endif
        let result = await Task.detached(priority: .userInitiated) {
            PermissionsScanner.scan()
        }.value
        self.items = result.items
        self.hasFullDiskAccess = result.hasFullDiskAccess
        self.hasScanned = true
        if focusedApp == nil { focusedApp = apps.first?.id }
    }

    #if DEBUG
    /// Sample rows for screenshots on machines without Full Disk Access.
    private static var demoItems: [PermissionItem] {
        let day: TimeInterval = 86_400
        func item(_ client: String, _ service: PermissionService, _ allowed: Bool = true, _ daysAgo: Double = 3) -> PermissionItem {
            PermissionItem(bundleID: client, service: service, allowed: allowed,
                           lastModified: Date().addingTimeInterval(-daysAgo * day),
                           appName: PermissionsScanner.resolveAppName(bundleID: client))
        }
        return [
            item("com.apple.Terminal", .fullDiskAccess, true, 40),
            item("com.apple.Terminal", .accessibility),
            item("com.apple.Terminal", .automation, true, 12),
            item("com.apple.dt.Xcode", .accessibility, true, 20),
            item("com.apple.dt.Xcode", .automation),
            item("com.apple.Safari", .camera),
            item("com.apple.Safari", .microphone),
            item("com.apple.Safari", .location, false, 60),
            item("us.zoom.xos", .screenRecording),
            item("us.zoom.xos", .camera),
            item("us.zoom.xos", .microphone),
            item("us.zoom.xos", .accessibility, false),
            item("ai.perplexity.mac", .screenRecording, true, 1),
            item("ai.perplexity.mac", .microphone, true, 1),
            item("com.microsoft.teams2", .screenRecording, false, 90),
            item("com.microsoft.teams2", .camera, true, 90),
            item("com.apple.TextEdit", .photos, false, 5),
            item("com.apple.TextEdit", .contacts, true, 5),
        ]
    }
    #endif
}

struct PermissionsSection: Identifiable {
    let service: PermissionService
    let items: [PermissionItem]
    var id: String { service.rawValue }
}

// MARK: - Details pane

struct PermissionsDetailsPane: View {
    let app: PermissionApp?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DetailsHeader(onClose: onClose)
            if let app {
                content(for: app)
            } else {
                ContentUnavailableView(
                    "No app selected",
                    systemImage: "hand.raised",
                    description: Text("Click an app to see every permission it holds.")
                )
            }
        }
    }

    private func content(for app: PermissionApp) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    PermissionAppIcon(client: app.id, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                        Text(app.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }

                if app.isTemporaryCopy {
                    note("This is a temporary copy macOS made while the app updated. The permission was recorded for that copy, so it may also appear under the app itself.")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    ForEach(app.items) { item in
                        permissionRow(item)
                    }
                }

                Text("Dates show when a permission last changed, not when the app used it. Change any of these in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func permissionRow(_ item: PermissionItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ServiceTile(service: item.service, size: 26)
                .opacity(item.allowed ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.service.displayName)
                        .fontWeight(.medium)
                    if item.allowed && item.service.isSensitive {
                        Text("Sensitive")
                            .font(.caption)
                            .foregroundStyle(PermissionTone.sensitive)
                    }
                }
                Text(item.service.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    AccessState(allowed: item.allowed)
                    if let last = item.lastModified {
                        Text("· \(last.formatted(.relative(presentation: .named)))")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 4)
            if let url = item.service.settingsURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Open \(item.service.displayName) in System Settings")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }
}
