import SwiftUI

/// Content panel for the Permissions tab. Takes over from the v0.3
/// placeholder: scans TCC.db and groups rows by service. Shows a dedicated
/// onboarding state when Full Disk Access hasn't been granted so neither
/// database is readable.
struct PermissionsView: View {
    @StateObject private var vm = PermissionsViewModel()

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
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(vm.sections) { section in
                    SectionView(section: section)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
            Circle()
                .fill(item.allowed ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.appName).font(.body)
                Text(item.bundleID).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let last = item.lastModified {
                Text(last, format: .relative(presentation: .named))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

@MainActor
final class PermissionsViewModel: ObservableObject {
    @Published private(set) var items: [PermissionItem] = []
    @Published private(set) var hasFullDiskAccess = false
    @Published private(set) var hasScanned = false

    var sections: [PermissionsSection] {
        let grouped = Dictionary(grouping: items, by: \.service)
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
