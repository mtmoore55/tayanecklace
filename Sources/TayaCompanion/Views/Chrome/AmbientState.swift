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

/// Environment-level reachability. Orthogonal to `SyncState` (which describes
/// the in-flight operation): this is "what can we reach right now." Drives
/// the top-of-screen StatusBanner, the necklace pill's warning glyph, and
/// the pending-on-capture behavior in DataStore. Taya's engineers will wire
/// real signals (NWPathMonitor + CoreBluetooth) into the same surface;
/// today the Profile sheet flips it for design review.
public enum ConnectivityStatus: String, CaseIterable, Identifiable, Equatable, Sendable {
    case ok
    case necklaceUnreachable
    case networkUnreachable
    case syncFailed

    public var id: String { rawValue }
    public var isOK: Bool { self == .ok }
}

public struct AmbientState: Sendable {
    public var userInitial: String
    /// Demo-grade display name surfaced in the Profile sheet header.
    /// Engineering replaces this with the real account identity.
    public var userName: String
    /// Demo-grade contact email surfaced in the Profile sheet header.
    public var userEmail: String
    public var necklaceBattery: Int          // 0…100
    /// True while the necklace is seated in its case/cradle. Overrides the
    /// percent-based tiering — a charging necklace at 5% reads as
    /// "charging," not "critical."
    public var isCharging: Bool
    public var weather: WeatherCondition
    public var highTempF: Int
    public var lowTempF: Int
    public var city: String
    /// True between 18:00 and 06:00 local — drives the Today nav to swap
    /// to moon + "Tonight".
    public var isNight: Bool
    /// Drives the necklace nav to morph into a rotating sync indicator.
    public var sync: SyncState
    /// Environment reachability — surfaces the StatusBanner when non-ok.
    public var connectivity: ConnectivityStatus
    /// Wall-clock timestamp of the last successful sync, used by the
    /// device sheet's "Last synced" row. Nil until the first sync lands.
    public var lastSyncedAt: Date?

    public init(
        userInitial: String = "E",
        userName: String = "Eliana Reyes",
        userEmail: String = "eliana@taya.app",
        necklaceBattery: Int = 72,
        isCharging: Bool = false,
        weather: WeatherCondition = .sunny,
        highTempF: Int = 72,
        lowTempF: Int = 58,
        city: String = "Oakland",
        isNight: Bool = false,
        sync: SyncState = .idle,
        connectivity: ConnectivityStatus = .ok,
        lastSyncedAt: Date? = nil
    ) {
        self.userInitial = userInitial
        self.userName = userName
        self.userEmail = userEmail
        self.necklaceBattery = necklaceBattery
        self.isCharging = isCharging
        self.weather = weather
        self.highTempF = highTempF
        self.lowTempF = lowTempF
        self.city = city
        self.isNight = isNight
        self.sync = sync
        self.connectivity = connectivity
        self.lastSyncedAt = lastSyncedAt
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

/// Display-level battery tier derived from `necklaceBattery` + `isCharging`.
/// Views render off this rather than the raw percent so a single source of
/// truth governs the pill tint, banner thresholds, and device-sheet copy.
public enum BatteryDisplayState: Equatable, Sendable {
    case charging
    case full        // ≥ 95
    case healthy     // 20…94
    case low         // 8…19
    case critical    // < 8
}

public extension AmbientState {
    var batteryDisplayState: BatteryDisplayState {
        if isCharging { return .charging }
        switch necklaceBattery {
        case ..<8:   return .critical
        case 8..<20: return .low
        case 95...:  return .full
        default:     return .healthy
        }
    }
}

/// SF Symbol variant that visually reflects a battery level. Charging
/// state takes precedence — the bolt-overlay glyph is the canonical
/// "necklace is on its cradle" affordance.
public func batterySystemImage(forPercent percent: Int, isCharging: Bool = false) -> String {
    if isCharging { return "battery.100percent.bolt" }
    switch percent {
    case ..<13:    return "battery.0percent"
    case 13..<38:  return "battery.25percent"
    case 38..<63:  return "battery.50percent"
    case 63..<88:  return "battery.75percent"
    default:       return "battery.100percent"
    }
}
