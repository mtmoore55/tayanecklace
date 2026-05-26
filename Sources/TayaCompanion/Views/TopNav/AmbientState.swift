import Foundation

/// Per-tab data that the nav icons render. Demo-grade — values are mocked
/// at construction. Phase 5+: wire real sources (battery via BLE, weather
/// via WeatherKit, user from a Profile model).
public enum SyncState: Equatable, Sendable {
    case idle
    case syncing(current: Int, total: Int)

    public var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
}

public struct AmbientState: Sendable {
    public var userInitial: String
    public var necklaceBattery: Int          // 0…100
    public var weather: WeatherCondition
    public var highTempF: Int
    public var lowTempF: Int
    public var city: String
    /// True between 18:00 and 06:00 local — drives the Today nav to swap
    /// to moon + "Tonight".
    public var isNight: Bool
    /// Drives the necklace nav to morph into a rotating sync indicator.
    public var sync: SyncState

    public init(
        userInitial: String = "E",
        necklaceBattery: Int = 72,
        weather: WeatherCondition = .sunny,
        highTempF: Int = 72,
        lowTempF: Int = 58,
        city: String = "Oakland",
        isNight: Bool = false,
        sync: SyncState = .idle
    ) {
        self.userInitial = userInitial
        self.necklaceBattery = necklaceBattery
        self.weather = weather
        self.highTempF = highTempF
        self.lowTempF = lowTempF
        self.city = city
        self.isNight = isNight
        self.sync = sync
    }

    public static let mock = AmbientState()

    /// Demo-grade night detection — 18:00 to 06:00 local time.
    public static func isCurrentlyNight(now: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        return hour >= 18 || hour < 6
    }
}

public enum WeatherCondition: Sendable {
    case sunny
    case partlyCloudy
    case cloudy
    case rainy
    case snowy

    public var systemImage: String {
        switch self {
        case .sunny:        return "sun.max"
        case .partlyCloudy: return "cloud.sun"
        case .cloudy:       return "cloud"
        case .rainy:        return "cloud.rain"
        case .snowy:        return "cloud.snow"
        }
    }
}

/// SF Symbol variant that visually reflects a battery level.
public func batterySystemImage(forPercent percent: Int) -> String {
    switch percent {
    case ..<13:    return "battery.0percent"
    case 13..<38:  return "battery.25percent"
    case 38..<63:  return "battery.50percent"
    case 63..<88:  return "battery.75percent"
    default:       return "battery.100percent"
    }
}
