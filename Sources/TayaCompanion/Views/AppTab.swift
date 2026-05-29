import Foundation

/// Three top-level destinations: Home, Chat, Moments. The Plus button
/// to the right of the bar is an action button, not a destination —
/// it doesn't appear in this enum.
public enum AppTab: String, Hashable, CaseIterable {
    case home, chat, moments

    public var index: Int { AppTab.allCases.firstIndex(of: self) ?? 0 }

    public static func at(_ index: Int) -> AppTab? {
        guard index >= 0, index < allCases.count else { return nil }
        return allCases[index]
    }
}

extension AppTab {
    var iconSystemName: String {
        switch self {
        case .home:    return "house"
        case .chat:    return "bubble.left"
        case .moments: return "clock"
        }
    }

    var iconSystemNameFilled: String {
        switch self {
        case .home:    return "house.fill"
        case .chat:    return "bubble.left.fill"
        case .moments: return "clock.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home:    return "Home"
        case .chat:    return "Chat"
        case .moments: return "Moments"
        }
    }
}
