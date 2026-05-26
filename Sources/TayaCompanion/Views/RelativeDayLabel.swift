import Foundation

enum RelativeDay {
    /// "today" / "yesterday" / "from Wed" / "Mar 12"
    static func label(from date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: now)
        let startOfDate = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0

        switch days {
        case ..<0:    return "today"
        case 0:       return "today"
        case 1:       return "yesterday"
        case 2...6:
            let fmt = DateFormatter()
            fmt.dateFormat = "EEE"
            return "from \(fmt.string(from: date))"
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return fmt.string(from: date)
        }
    }

    /// Section-header form: "Today" / "Yesterday" / "Saturday" / "Mar 12"
    static func sectionLabel(from date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: now)
        let startOfDate = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startOfDate, to: startOfNow).day ?? 0

        switch days {
        case ..<0, 0: return "Today"
        case 1:       return "Yesterday"
        case 2...6:
            let fmt = DateFormatter()
            fmt.dateFormat = "EEEE"
            return fmt.string(from: date)
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return fmt.string(from: date)
        }
    }
}
