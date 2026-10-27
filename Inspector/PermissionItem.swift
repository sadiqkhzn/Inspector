import Foundation

/// The subset of macOS privacy "services" (as TCC.db calls them) that Inspector
/// surfaces in the Permissions view. Each service corresponds to a Privacy &
/// Security section in System Settings.
enum PermissionService: String, CaseIterable, Hashable {
    case camera           = "kTCCServiceCamera"
    case microphone       = "kTCCServiceMicrophone"
    case screenRecording  = "kTCCServiceScreenCapture"
    case accessibility    = "kTCCServiceAccessibility"
    case location         = "kTCCServiceLocation"
    case fullDiskAccess   = "kTCCServiceSystemPolicyAllFiles"
    case automation       = "kTCCServiceAppleEvents"
    case inputMonitoring  = "kTCCServiceListenEvent"
    case contacts         = "kTCCServiceAddressBook"
    case calendar         = "kTCCServiceCalendar"
    case photos           = "kTCCServicePhotos"
    case reminders        = "kTCCServiceReminders"

    var displayName: String {
        switch self {
        case .camera:           return "Camera"
        case .microphone:       return "Microphone"
        case .screenRecording:  return "Screen Recording"
        case .accessibility:    return "Accessibility"
        case .location:         return "Location Services"
        case .fullDiskAccess:   return "Full Disk Access"
        case .automation:       return "Automation"
        case .inputMonitoring:  return "Input Monitoring"
        case .contacts:         return "Contacts"
        case .calendar:         return "Calendars"
        case .photos:           return "Photos"
        case .reminders:        return "Reminders"
        }
    }

    /// One-word name for tight spots: tooltips on the glyph strip, VoiceOver lists.
    var shortName: String {
        switch self {
        case .camera:           return "Camera"
        case .microphone:       return "Microphone"
        case .screenRecording:  return "Screen"
        case .accessibility:    return "Accessibility"
        case .location:         return "Location"
        case .fullDiskAccess:   return "Full Disk"
        case .automation:       return "Automation"
        case .inputMonitoring:  return "Input"
        case .contacts:         return "Contacts"
        case .calendar:         return "Calendars"
        case .photos:           return "Photos"
        case .reminders:        return "Reminders"
        }
    }

    /// The glyph System Settings › Privacy & Security uses for the same pane.
    var symbol: String {
        switch self {
        case .camera:           return "camera.fill"
        case .microphone:       return "mic.fill"
        case .screenRecording:  return "rectangle.dashed.badge.record"
        case .accessibility:    return "accessibility"
        case .location:         return "location.fill"
        case .fullDiskAccess:   return "externaldrive.fill"
        case .automation:       return "gearshape.2.fill"
        case .inputMonitoring:  return "keyboard.fill"
        case .contacts:         return "person.crop.circle.fill"
        case .calendar:         return "calendar"
        case .photos:           return "photo.fill"
        case .reminders:        return "list.bullet"
        }
    }

    /// One sentence on what the permission lets an app do, for the details pane.
    var explanation: String {
        switch self {
        case .camera:           return "Can turn on the camera."
        case .microphone:       return "Can listen through the microphone."
        case .screenRecording:  return "Can see everything on your screen and record system audio."
        case .accessibility:    return "Can control your Mac: click, type and read other apps' windows."
        case .location:         return "Can see where your Mac is."
        case .fullDiskAccess:   return "Can read every file, including Mail, Messages and Safari data."
        case .automation:       return "Can send commands to other apps."
        case .inputMonitoring:  return "Can see every key you press, in any app."
        case .contacts:         return "Can read your contacts."
        case .calendar:         return "Can read and change your calendars."
        case .photos:           return "Can see your photo library."
        case .reminders:        return "Can read and change your reminders."
        }
    }

    /// Services that give an app wide read/write power over user data or input.
    /// Shown with a stronger badge in the UI.
    var isSensitive: Bool {
        switch self {
        case .fullDiskAccess, .accessibility, .inputMonitoring,
             .screenRecording, .automation:
            return true
        default:
            return false
        }
    }

    /// Deep-link that bounces straight into System Settings → Privacy & Security
    /// for this specific service. Verified against the macOS 13+ URL scheme —
    /// older macOS versions open the parent Privacy pane instead, which is a
    /// graceful fallback rather than an error.
    var settingsURL: URL? {
        let anchor: String
        switch self {
        case .camera:          anchor = "Privacy_Camera"
        case .microphone:      anchor = "Privacy_Microphone"
        case .screenRecording: anchor = "Privacy_ScreenCapture"
        case .accessibility:   anchor = "Privacy_Accessibility"
        case .location:        anchor = "Privacy_LocationServices"
        case .fullDiskAccess:  anchor = "Privacy_AllFiles"
        case .automation:      anchor = "Privacy_Automation"
        case .inputMonitoring: anchor = "Privacy_ListenEvent"
        case .contacts:        anchor = "Privacy_Contacts"
        case .calendar:        anchor = "Privacy_Calendars"
        case .photos:          anchor = "Privacy_Photos"
        case .reminders:       anchor = "Privacy_Reminders"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
    }

    static func from(tccService: String) -> PermissionService? {
        PermissionService.allCases.first { $0.rawValue == tccService }
    }
}

/// Mirrors the Storage view's Safe / Review / Keep system — a single-word
/// chip the UI puts next to each row so users can scan at a glance.
enum PermissionTier: String {
    /// The user denied the request. No action needed.
    case denied
    /// Granted and touched recently. Standard case for apps you actively use.
    case granted
    /// Granted but not touched in >= 30 days. Candidate for revocation.
    case stale
    /// Granted *and* the service is one of the sensitive ones (Full Disk
    /// Access, Accessibility, Input Monitoring, Screen Recording, Automation).
    /// Shown louder.
    case risky

    var label: String {
        switch self {
        case .denied:  return "Denied"
        case .granted: return "Granted"
        case .stale:   return "Stale"
        case .risky:   return "Risky"
        }
    }
}

/// One row in the Permissions view — "App X has (or doesn't have) permission
/// Y, last touched at time T."
struct PermissionItem: Identifiable, Hashable {
    let bundleID: String
    let service: PermissionService
    let allowed: Bool
    let lastModified: Date?
    /// Human-friendly name (resolved via NSWorkspace from the bundle ID when
    /// possible; falls back to the bundle ID itself).
    let appName: String

    var id: String { "\(bundleID)|\(service.rawValue)" }

    /// Classification used by the UI chip. Not persisted — derived on the fly
    /// so the "Stale" cut-off can shift later without a scanner change.
    var tier: PermissionTier {
        guard allowed else { return .denied }
        if service.isSensitive { return .risky }
        if let last = lastModified,
           Date().timeIntervalSince(last) > 30 * 24 * 60 * 60 {
            return .stale
        }
        return .granted
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: PermissionItem, b: PermissionItem) -> Bool { a.id == b.id }
}
