import Foundation

/// User control over which pushes Taya is allowed to send. Each flag maps
/// to a category the app already generates internally — tasks coming due,
/// the daily reflection, fresh `Suggestion`s, resurfaced moments, and
/// operational pings about the necklace. Defaults are all-on; the user
/// dials back in Profile.
public struct NotificationPreferences: Hashable, Sendable {
    public var tasks: Bool
    public var reflections: Bool
    public var suggestions: Bool
    public var resurfaced: Bool
    public var deviceAlerts: Bool

    public init(
        tasks: Bool = true,
        reflections: Bool = true,
        suggestions: Bool = true,
        resurfaced: Bool = true,
        deviceAlerts: Bool = true
    ) {
        self.tasks = tasks
        self.reflections = reflections
        self.suggestions = suggestions
        self.resurfaced = resurfaced
        self.deviceAlerts = deviceAlerts
    }
}

/// One row in the Profile notifications surface. Splits the four content
/// categories from the single operational one so the UI can render them
/// in two visually-grouped sections.
public enum NotificationCategory: String, CaseIterable, Identifiable, Sendable {
    case tasks, reflections, suggestions, resurfaced, deviceAlerts

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .tasks:        return "Task reminders"
        case .reflections:  return "Reflections"
        case .suggestions:  return "Suggestions"
        case .resurfaced:   return "Forgotten threads"
        case .deviceAlerts: return "Device alerts"
        }
    }

    /// SF Symbol picked to echo each category's home in the app — the
    /// task ring, the moon-tinted recap, sparkles for the For-You lens,
    /// the clock-arrow for revisit, and a bell for operational pings.
    public var systemImage: String {
        switch self {
        case .tasks:        return "checkmark.circle"
        case .reflections:  return "moon.stars"
        case .suggestions:  return "sparkles"
        case .resurfaced:   return "clock.arrow.circlepath"
        case .deviceAlerts: return "bell.badge"
        }
    }

    /// `deviceAlerts` lives in its own group because it's operational
    /// (battery, sync, disconnect) rather than content the app surfaces.
    /// Users almost always want different defaults for those.
    public var isDeviceAlert: Bool { self == .deviceAlerts }

    /// Categories that belong to the main "Notifications" group, in
    /// display order.
    public static let content: [NotificationCategory] = [
        .tasks, .reflections, .suggestions, .resurfaced
    ]
}
