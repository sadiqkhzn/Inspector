import SwiftUI

@MainActor
final class StorageViewModel: ObservableObject {
    @Published var items: [CleanupItem] = []
    @Published var disk = DiskSnapshot(totalBytes: 0, freeBytes: 0)
    @Published var isScanning = false
    @Published var statusMessage: String?

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

struct ContentView: View {
    @StateObject private var vm = StorageViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Header(disk: vm.disk)
            Divider()
            Toolbar(vm: vm)
            Divider()
            if vm.isScanning {
                ProgressView("Scanning…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.items.isEmpty {
                EmptyState()
            } else {
                ItemList(vm: vm)
            }
            if let msg = vm.statusMessage {
                Divider()
                Text(msg).font(.callout).foregroundStyle(.secondary).padding(10)
            }
        }
        .task { await vm.refresh() }
    }
}

private struct Header: View {
    let disk: DiskSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Inspector").font(.title2).bold()
                Text("See what macOS hides.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(disk.formattedFree) free")
                    .font(.title3).bold()
                Text("\(disk.formattedUsed) of \(disk.formattedTotal) used")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

private struct Toolbar: View {
    @ObservedObject var vm: StorageViewModel

    var body: some View {
        HStack {
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }

            Button {
                vm.selectAllSafe()
            } label: {
                Label("Select all safe", systemImage: "checkmark.circle")
            }
            .disabled(vm.items.allSatisfy { $0.safety != .safe })

            Spacer()

            if vm.selectedBytes > 0 {
                Text("Selected: \(vm.formattedSelected)")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Button {
                Task { await vm.reclaimSelected() }
            } label: {
                Label("Reclaim selected", systemImage: "trash")
            }
            .keyboardShortcut(.return)
            .disabled(vm.selectedBytes == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Nothing worth cleaning right now.").font(.headline)
            Text("Known caches and leftovers are below the size threshold.")
                .font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ItemList: View {
    @ObservedObject var vm: StorageViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach($vm.items) { $item in
                    ItemRow(item: $item)
                    Divider()
                }
            }
        }
    }
}

private struct ItemRow: View {
    @Binding var item: CleanupItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $item.selected)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.name).font(.body).bold()
                    SafetyBadge(level: item.safety)
                    Text(item.category.rawValue)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(item.path)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                Text(item.whatItIs).font(.callout)
                Text("If removed: \(item.whatHappensIfRemoved)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.formattedSize).font(.body).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { item.selected.toggle() }
    }
}

private struct SafetyBadge: View {
    let level: SafetyLevel

    var color: Color {
        switch level {
        case .safe:   return .green
        case .review: return .yellow
        case .keep:   return .red
        }
    }

    var body: some View {
        Text(level.label)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
