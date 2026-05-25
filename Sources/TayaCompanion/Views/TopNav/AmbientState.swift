import Foundation

/// Per-tab data that the nav icons render. Demo-grade — values are mocked
/// at construction. Phase 5+: wire real sources (battery via BLE, weather
/// via WeatherKit, user from a Profile model).
public struct AmbientState: Sendable {
    public var userInitial: String
    public var necklaceBattery: Int          // 0…100
    public var weather: WeatherCondition

    public init(
        userInitial: String = "E",
        necklaceBattery: Int = 72,
        weather: WeatherCondition = .sunny
    ) {
        self.userInitial = userInitial
        self.necklaceBattery = necklaceBattery
        self.weather = weather
    }

    public static let mock = AmbientState()
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
