import SwiftUI

/// Content panel for the Permissions tab. Takes over from the v0.3
/// placeholder: scans TCC.db and groups rows by service. Shows a dedicated
/// onboarding state when Full Disk Access hasn't been granted so neither
/// database is readable.
struct PermissionsView: View {
    @ObservedObject var vm: PermissionsViewModel

    init(vm: PermissionsViewModel? = nil) {
        // Prefer injection (so ContentView can share the vm with the toolbar
        // search field); fall back to a local one when the view is used alone.
        if let vm {
            _vm = ObservedObject(wrappedValue: vm)
        } else {
            _vm = ObservedObject(wrappedValue: PermissionsViewModel())
        }
    }

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
            Text("Reading TCC database…")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fullDiskAccessNeeded: some View {
        ContentUnavailableView {
            Label("Grant Full Disk Access", systemImage: "lock.shield")
        } description: {
            Text("Inspector needs Full Disk Access to read macOS's privacy database and show which apps have camera, mic, screen recording and other permissions.")
        } actions: {
            Button("Open System Settings → Privacy & Security") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Try again") { Task { await vm.load() } }
                .buttonStyle(.borderless)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No permissions found",
            systemImage: "hand.raised",
            description: Text("The TCC database opened but contains no entries. That's unusual — try granting a permission to any app and running again.")
        )
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                summary
                ForEach(vm.sections) { section in
                    SectionView(section: section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var summary: some View {
        let risky   = vm.items.filter { $0.tier == .risky }.count
        let stale   = vm.items.filter { $0.tier == .stale }.count
        let granted = vm.items.filter { $0.tier == .granted }.count
        let denied  = vm.items.filter { $0.tier == .denied }.count
        return HStack(spacing: 20) {
            summaryCell(label: "Risky", count: risky, color: .orange)
            summaryCell(label: "Stale", count: stale, color: .yellow)
            summaryCell(label: "Granted", count: granted, color: .green)
            summaryCell(label: "Denied", count: denied, color: .secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }

    private func summaryCell(label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(.system(size: 28, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SectionView: View {
    let section: PermissionsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: section.service.symbol)
                    .foregroundStyle(section.service.isSensitive ? Color.orange : .secondary)
                Text(section.service.displayName)
                    .font(.headline)
                Text("\(section.items.count)")
                    .font(.caption)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = section.service.settingsURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open in Settings", systemImage: "arrow.up.right.square")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Open \(section.service.displayName) in System Settings → Privacy & Security")
                }
            }
            VStack(spacing: 0) {
                ForEach(section.items) { item in
                    row(item)
                    if item.id != section.items.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        }
    }

    private func row(_ item: PermissionItem) -> some View {
        HStack(spacing: 10) {
            AppIcon(bundleID: item.bundleID)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.appName).font(.body)
                Text(item.bundleID).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            TierChip(tier: item.tier)
            if let last = item.lastModified {
                Text(last, format: .relative(presentation: .named))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(minWidth: 88, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

/// Visual badge mirroring Storage's Safe / Review / Keep system but tuned for
/// the Permissions domain.
private struct TierChip: View {
    let tier: PermissionTier

    private var color: Color {
        switch tier {
        case .denied:  return .secondary
        case .granted: return .green
        case .stale:   return .yellow
        case .risky:   return .orange
        }
    }

    var body: some View {
        Text(tier.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

/// Looks up and renders the installed app's icon for a bundle ID via
/// NSWorkspace. Falls back to a neutral SF Symbol tile when the app can't
/// be resolved (bundle isn't installed any more, isn't registered, etc.).
private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let nsImage = Self.icon(for: bundleID) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }

    private static func icon(for bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

@MainActor
final class PermissionsViewModel: ObservableObject {
    @Published private(set) var items: [PermissionItem] = []
    @Published private(set) var hasFullDiskAccess = false
    @Published private(set) var hasScanned = false
    @Published var searchText: String = ""

    private var filtered: [PermissionItem] {
        guard !searchText.isEmpty else { return items }
        let needle = searchText
        return items.filter { item in
            item.appName.localizedCaseInsensitiveContains(needle)
                || item.bundleID.localizedCaseInsensitiveContains(needle)
                || item.service.displayName.localizedCaseInsensitiveContains(needle)
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

    func load() async {
        let result = await Task.detached(priority: .userInitiated) {
            PermissionsScanner.scan()
        }.value
        self.items = result.items
        self.hasFullDiskAccess = result.hasFullDiskAccess
        self.hasScanned = true
    }
}

struct PermissionsSection: Identifiable {
    let service: PermissionService
    let items: [PermissionItem]
    var id: String { service.rawValue }
}
