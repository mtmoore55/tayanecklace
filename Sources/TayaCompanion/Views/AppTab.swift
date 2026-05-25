import Foundation

/// The five top-level pages, ordered left-to-right as they appear in the
/// horizontal pager and the top nav.
public enum AppTab: String, Hashable, CaseIterable {
    case user, necklace, today, chats, moments

    public var index: Int { AppTab.allCases.firstIndex(of: self) ?? 0 }

    public static func at(_ index: Int) -> AppTab? {
        guard index >= 0, index < allCases.count else { return nil }
        return allCases[index]
    }
}

extension AppTab {
    /// SF Symbol used for compact (and expanded) display in the top nav.
    var iconSystemName: String {
        switch self {
        case .user:     return "person"
        case .necklace: return "battery.75percent"
        case .today:    return "sun.max"
        case .chats:    return "bubble.left"
        case .moments:  return "clock"
        }
    }

    /// Label rendered inside the expanded pill. `.today` is dynamic — uses
    /// the current date in "MMM d" format ("May 26").
    func label(now: Date = Date()) -> String {
        switch self {
        case .user:     return "Profile"
        case .necklace: return "Necklace"
        case .today:    return Self.dateLabel(now)
        case .chats:    return "Chats"
        case .moments:  return "Moments"
        }
    }

    private static func dateLabel(_ now: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: now)
    }

    /// Rough intrinsic width of the label at 13pt semibold. Used by the
    /// NavItem to lerp the text's frame width from 0 → estimated, so the
    /// HStack reports an accurate intrinsic width to its parent at every
    /// stage of the expansion and the content can be centered.
    var estimatedLabelWidth: CGFloat {
        switch self {
        case .user:     return 50    // "Profile"
        case .necklace: return 64    // "Necklace"
        case .today:    return 58    // "MMM d" e.g. "May 25"
        case .chats:    return 42    // "Chats"
        case .moments:  return 66    // "Moments"
        }
    }
}
