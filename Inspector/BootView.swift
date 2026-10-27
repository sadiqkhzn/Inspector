import SwiftUI
import AppKit

struct BootView: View {
    @StateObject private var vm = BootViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task { vm.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Boot items")
                .font(.title3.weight(.semibold))
            Text("\(vm.items.count) agents in ~/Library/LaunchAgents · \(vm.enabledCount) enabled")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.badge.automatic")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No user LaunchAgents found.")
                .font(.headline)
            Text("System-wide /Library/LaunchAgents and LaunchDaemons will come in a later release.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.items) { item in
                    row(item)
                    Divider().padding(.leading, 20)
                }
            }
        }
    }

    private func row(_ item: BootItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: item.enabled ? "circle.fill" : "circle.slash")
                .foregroundStyle(item.enabled ? Color.green : Color.secondary)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.owner).font(.body.weight(.semibold))
                    Text(item.label).font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text(item.programDisplay)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 10) {
                    if item.runAtLoad { tag("Run at load") }
                    if item.keepAlive { tag("Keep alive") }
                    if item.disabled { tag("Disabled").foregroundStyle(.red) }
                }
            }
            Spacer()
            Button("Reveal") { reveal(item.plistURL) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12)))
    }

    private func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

@MainActor
final class BootViewModel: ObservableObject {
    @Published private(set) var items: [BootItem] = []

    var enabledCount: Int { items.filter(\.enabled).count }

    func load() {
        items = BootScanner.scan()
    }
}
