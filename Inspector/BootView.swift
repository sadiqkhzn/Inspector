import SwiftUI
import AppKit

@MainActor
final class BootViewModel: ObservableObject {
    enum StatusFilter: Hashable {
        case all, enabled, disabled
    }

    @Published private(set) var items: [BootItem] = []
    @Published private(set) var hasLoaded = false
    @Published var searchText: String = "" { didSet { keepFocusVisible() } }
    @Published var filter: StatusFilter = .all { didSet { keepFocusVisible() } }
    @Published var sourceFilter: BootSource? = nil { didSet { keepFocusVisible() } }
    @Published var focusedID: BootItem.ID?

    var visibleItems: [BootItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            matches(item, filter)
                && (sourceFilter == nil || item.source == sourceFilter)
                && (query.isEmpty || item.searchableText.localizedCaseInsensitiveContains(query))
        }
    }

    /// Visible items grouped by developer, in the order the scanner ranked them.
    var groups: [BootGroup] {
        var order: [String] = []
        var byOwner: [String: [BootItem]] = [:]
        for item in visibleItems {
            if byOwner[item.owner] == nil { order.append(item.owner) }
            byOwner[item.owner, default: []].append(item)
        }
        return order.map { BootGroup(owner: $0, items: byOwner[$0] ?? []) }
    }

    func count(forSource source: BootSource) -> Int {
        items.filter { $0.source == source }.count
    }

    var enabledCount: Int { items.filter(\.enabled).count }
    var focusedItem: BootItem? { items.first { $0.id == focusedID } }

    func count(for filter: StatusFilter) -> Int { items.filter { matches($0, filter) }.count }

    func load() {
        items = BootScanner.scan()
        if focusedItem == nil { focusedID = groups.first?.items.first?.id }
        hasLoaded = true
    }

    func moveFocus(by offset: Int) {
        let ids = groups.flatMap(\.items).map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = focusedID, let index = ids.firstIndex(of: current) else {
            focusedID = ids.first
            return
        }
        focusedID = ids[min(max(index + offset, 0), ids.count - 1)]
    }

    /// When a search or filter hides the focused agent, the details pane follows the first visible one.
    private func keepFocusVisible() {
        let visible = visibleItems
        if !visible.contains(where: { $0.id == focusedID }) { focusedID = groups.first?.items.first?.id }
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
        if let interval = startInterval, interval > 0 { return Self.every(interval) }
        if let calendarSummary { return calendarSummary }
        if runAtLoad { return source == .systemDaemon ? "At startup" : "At login" }
        return "When needed"
    }

    var statusNote: String {
        if disabled { return "Turned off in its plist (Disabled = true). launchd won't start it." }
        if keepAlive { return "Starts with your Mac and launchd restarts it whenever it quits." }
        if let interval = startInterval, interval > 0 { return "launchd runs it \(Self.every(interval).lowercased()), whether or not an app is open." }
        if let calendarSummary { return "launchd runs it on a schedule: \(calendarSummary.lowercased())." }
        if runAtLoad { return source == .systemDaemon ? "Starts when your Mac starts up." : "Starts when you log in." }
        return "Registered with launchd, but only starts when another program asks for it."
    }

    private static func every(_ seconds: Int) -> String {
        switch seconds {
        case 86_400: return "Daily"
        case 604_800: return "Weekly"
        case let s where s % 3_600 == 0: return s == 3_600 ? "Every hour" : "Every \(s / 3_600) h"
        case let s where s % 60 == 0: return "Every \(s / 60) min"
        default: return "Every \(seconds) s"
        }
    }

    /// The program's own name: "GoogleUpdater", "postgres", "steamclean".
    var programName: String {
        guard let path = executablePath else { return label }
        let url = URL(fileURLWithPath: path)
        if let app = url.pathComponents.lastIndex(where: { $0.hasSuffix(".app") }),
           url.pathComponents.count - app <= 3 {
            // ".../GoogleUpdater.app/Contents/MacOS/GoogleUpdater" reads best as the app.
            return (url.pathComponents[app] as NSString).deletingPathExtension
        }
        return url.lastPathComponent
    }

    var trustLabel: String {
        switch signatureStatus {
        case .valid:    return signer.map { "Signed · \($0)" } ?? "Signed (ad hoc)"
        case .unsigned: return "Unsigned"
        case .missing:  return "Program missing"
        case .unknown:  return "Couldn't check"
        }
    }

    var trustTint: Color {
        switch signatureStatus {
        case .valid:    return signer == nil ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen)
        case .unsigned: return Color(nsColor: .systemOrange)
        case .missing, .unknown: return Color(nsColor: .systemGray)
        }
    }

    var trustNote: String {
        switch signatureStatus {
        case .valid where signer != nil:
            return "Its program carries a valid signature from \(signer!), so it hasn't been changed since they shipped it."
        case .valid:
            return "Its program is signed, but only ad hoc, with no developer named. Usual for tools you built or installed with Homebrew."
        case .unsigned:
            return "Its program has no valid signature. Normal for some command-line tools; worth a look if you don't recognise it."
        case .missing:
            return "The program it points to isn't on this Mac any more. Usually a leftover from an app you removed."
        case .unknown:
            return "Inspector couldn't read this program's signature."
        }
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
                    Text("Nothing in ~/Library/LaunchAgents, /Library/LaunchAgents or /Library/LaunchDaemons.")
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

    /// One row: where the item lives on the left, enabled / disabled as a menu on the right.
    private var filterBar: some View {
        HStack(spacing: 12) {
            PillPicker(
                selection: $vm.sourceFilter,
                options: [
                    (value: nil, label: "All", count: vm.items.count),
                    (value: .userAgent, label: "User", count: vm.count(forSource: .userAgent)),
                    (value: .systemAgent, label: "System", count: vm.count(forSource: .systemAgent)),
                    (value: .systemDaemon, label: "Daemon", count: vm.count(forSource: .systemDaemon)),
                ]
            )
            .help("User: ~/Library/LaunchAgents · System: /Library/LaunchAgents · Daemon: /Library/LaunchDaemons")
            Spacer(minLength: 12)
            Picker("Show", selection: $vm.filter) {
                Text("Enabled and disabled").tag(BootViewModel.StatusFilter.all)
                Text("Enabled only (\(vm.count(for: .enabled)))").tag(BootViewModel.StatusFilter.enabled)
                Text("Disabled only (\(vm.count(for: .disabled)))").tag(BootViewModel.StatusFilter.disabled)
            }
            .pickerStyle(.menu)
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
        let signed = vm.items.filter { $0.signatureStatus == .valid && $0.signer != nil }.count
        let missing = vm.items.filter { $0.signatureStatus == .missing || $0.signatureStatus == .unknown }.count
        let unsigned = total - signed - missing

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Starts with your Mac")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(enabled)")
                        .font(.system(size: 44, weight: .semibold))
                        .tracking(-1)
                        .monospacedDigit()
                    Text(enabled == 1 ? "item" : "items")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("enabled, from \(Set(vm.items.map(\.owner)).count) developers")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 8)
                        .layoutPriority(-1)
                }
            }

            GeometryReader { geo in
                let width = geo.size.width - 4
                let share = { (n: Int) in total > 0 ? width * CGFloat(n) / CGFloat(total) : 0 }
                HStack(spacing: 2) {
                    Capsule().fill(Color(nsColor: .systemGreen).opacity(0.6)).frame(width: share(signed))
                    Capsule().fill(Color(nsColor: .systemOrange).opacity(0.65)).frame(width: share(unsigned))
                    Capsule().fill(Color.primary.opacity(0.15))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel("\(signed) signed by a developer, \(unsigned) unsigned or ad hoc, \(missing) with a missing program")

            HStack(spacing: 18) {
                LegendDot(color: Color(nsColor: .systemGreen), text: "Signed by a developer \(signed)")
                LegendDot(color: Color(nsColor: .systemOrange), text: "Unsigned or ad hoc \(unsigned)")
                LegendDot(color: Color.primary.opacity(0.3), text: "Program missing \(missing)")
            }
            .fixedSize()
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
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
                    ForEach(vm.groups) { group in
                        if group.id != vm.groups.first?.id {
                            Divider()
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                        }
                        GroupHeader(group: group)
                            .padding(.top, group.id == vm.groups.first?.id ? 4 : 8)
                        ForEach(group.items) { item in
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
            BootIcon(size: 26, item: item)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.programName)
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

            if item.source != .userAgent {
                SourceBadge(source: item.source)
                    .fixedSize()
            }

            HStack(spacing: 6) {
                Circle().fill(item.trustTint).frame(width: 6, height: 6)
                Text(item.trustLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 190, alignment: .leading)
            .help(item.trustNote)

            Text(item.trigger)
                .foregroundStyle(item.disabled ? .tertiary : .secondary)
                .lineLimit(1)
                .frame(width: 112, alignment: .trailing)
                .help(item.statusNote)

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

struct BootGroup: Identifiable {
    let owner: String
    let items: [BootItem]
    var id: String { owner }
}

private struct GroupHeader: View {
    let group: BootGroup

    var body: some View {
        HStack(spacing: 8) {
            if let item = group.items.first(where: { BootIcon.resolveIcon(for: $0) != nil }) ?? group.items.first {
                BootIcon(size: 18, item: item)
            }
            Text(group.owner)
                .font(.callout.weight(.semibold))
            Text("\(group.items.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct SourceBadge: View {
    let source: BootSource

    private var tint: Color {
        switch source {
        case .userAgent:    return .secondary
        case .systemAgent:  return .yellow
        case .systemDaemon: return .orange
        }
    }

    private var shortLabel: String {
        switch source {
        case .userAgent:    return "User"
        case .systemAgent:  return "System"
        case .systemDaemon: return "Daemon"
        }
    }

    var body: some View {
        Text(shortLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
            .help("Lives at \(source.directory)")
    }
}

struct BootIcon: View {
    let item: BootItem
    let size: CGFloat

    init(size: CGFloat, item: BootItem) {
        self.size = size
        self.item = item
    }

    var body: some View {
        if let icon = Self.resolveIcon(for: item) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            let fallback = Self.fallback(for: item)
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(fallback.tint.opacity(0.16))
                .overlay(
                    Image(systemName: fallback.symbol)
                        .font(.system(size: size * 0.46, weight: .semibold))
                        .foregroundStyle(fallback.tint)
                )
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    /// The owning app's real icon. Tried in order: the `.app` the program lives
    /// in, an app whose bundle ID is the label, then the vendor's main app.
    static func resolveIcon(for item: BootItem) -> NSImage? {
        let key = item.id as NSString
        if let hit = clients.object(forKey: key) { return AppIconCache.icon(forClient: hit as String) }
        let client = appClient(for: item) ?? ""
        clients.setObject(client as NSString, forKey: key)
        return AppIconCache.icon(forClient: client)
    }

    private static let clients = NSCache<NSString, NSString>()

    private static func appClient(for item: BootItem) -> String? {
        if let path = item.executablePath,
           let app = URL(fileURLWithPath: path).pathComponents.lastIndex(where: { $0.hasSuffix(".app") }) {
            let appPath = NSString.path(withComponents: Array(URL(fileURLWithPath: path).pathComponents[...app]))
            if FileManager.default.fileExists(atPath: appPath) { return appPath }
        }
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.label) != nil { return item.label }
        let vendor = item.label.split(separator: ".").prefix(2).joined(separator: ".").lowercased()
        return vendorApps[vendor]?.first { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    /// Reverse-DNS vendor prefix → the apps whose icon stands for that vendor's agents.
    private static let vendorApps: [String: [String]] = [
        "com.google": ["com.google.Chrome", "com.google.drivefs", "com.google.android.studio"],
        "com.adobe": ["com.adobe.acc.AdobeCreativeCloud", "com.adobe.Acrobat.Pro", "com.adobe.Reader"],
        "com.microsoft": ["com.microsoft.autoupdate2", "com.microsoft.teams2", "com.microsoft.Outlook", "com.microsoft.Word", "com.microsoft.VSCode", "com.microsoft.edgemac"],
        "us.zoom": ["us.zoom.xos"],
        "com.valvesoftware": ["com.valvesoftware.steam"],
        "com.docker": ["com.docker.docker"],
        "com.spotify": ["com.spotify.client"],
        "com.getdropbox": ["com.getdropbox.dropbox"],
        "com.dropbox": ["com.getdropbox.dropbox"],
        "com.logi": ["com.logi.optionsplus", "com.logitech.manager.daemon"],
        "com.logitech": ["com.logi.optionsplus", "com.logitech.manager.daemon"],
        "com.1password": ["com.1password.1password"],
        "com.agilebits": ["com.1password.1password"],
        "com.raycast": ["com.raycast.macos"],
        "com.figma": ["com.figma.Desktop"],
        "com.jetbrains": ["com.jetbrains.toolbox"],
        "com.parallels": ["com.parallels.desktop.console"],
        "com.vmware": ["com.vmware.fusion"],
        "io.tailscale": ["io.tailscale.ipn.macsys", "io.tailscale.ipn.macos"],
        "com.grammarly": ["com.grammarly.ProjectLlama"],
        "com.teamviewer": ["com.teamviewer.TeamViewer"],
        "com.nordvpn": ["com.nordvpn.macos"],
        "com.malwarebytes": ["com.malwarebytes.mbam.frontend.application"],
        "com.elgato": ["com.elgato.StreamDeck"],
        "org.mozilla": ["org.mozilla.firefox"],
        "com.brave": ["com.brave.Browser"],
        "com.objective-see": ["com.objective-see.lulu.app"],
        "com.setapp": ["com.setapp.DesktopClient"],
        "com.macpaw": ["com.macpaw.CleanMyMac5", "com.macpaw.CleanMyMac4"],
        "com.github": ["com.github.GitHubClient"],
        "com.cisco": ["com.cisco.secureclient.gui"],
        "com.paloaltonetworks": ["com.paloaltonetworks.GlobalProtect.client"],
        "com.crowdstrike": ["com.crowdstrike.falcon.App"],
    ]

    /// No app to borrow an icon from: Homebrew gets its mug, other command-line
    /// programs a terminal, and a missing program a question mark.
    private static func fallback(for item: BootItem) -> (symbol: String, tint: Color) {
        if item.signatureStatus == .missing { return ("questionmark", .secondary) }
        let path = item.executablePath ?? ""
        if item.label.hasPrefix("homebrew.") || path.hasPrefix("/opt/homebrew/") || path.contains("/Cellar/") || path.hasPrefix("/usr/local/opt/") {
            return ("mug.fill", Color(nsColor: .systemOrange))
        }
        return ("terminal.fill", .secondary)
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
                BootIcon(size: 44, item: item)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.programName)
                        .font(.title3.weight(.semibold))
                    Text("\(item.owner) · \(item.source.label)")
                        .foregroundStyle(.secondary)
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

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(item.trustTint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.trustLabel).fontWeight(.semibold)
                    Text(item.trustNote).foregroundStyle(.secondary)
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
                    Text("Label").foregroundStyle(.secondary)
                    Text(item.label)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
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
