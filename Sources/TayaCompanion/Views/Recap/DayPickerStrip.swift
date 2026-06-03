import SwiftUI

/// Horizontal day strip used on Home and in the Recap detail sheet.
/// Each cell shows the weekday letter and day-of-month number, with a
/// small dot when the day has any activity. The selected day gets a
/// pill background.
///
/// Two layouts:
/// - `.fitted` — equal-width cells distributed edge to edge, no scroll.
///   Used on Home where the strip stays compact and shows a handful of
///   recent days.
/// - `.scrollable` — fixed-width cells in a horizontal `ScrollView`,
///   auto-centering the selection. Used in the detail sheet where the
///   user can swipe through more days.
///
/// Binary active/inactive in v1; weighted-density dot is Phase 2.
struct DayPickerStrip: View {
    enum Layout { case fitted, scrollable }

    let days: [Date]
    @Binding var selectedDay: Date
    /// Pass-through so the host can answer activity from
    /// `store.recap(for: day).hasActivity` — one source of truth.
    var activityFor: (Date) -> Bool
    var layout: Layout = .scrollable

    private static let cal = Calendar.current

    var body: some View {
        switch layout {
        case .fitted:        fittedBody
        case .scrollable:    scrollableBody
        }
    }

    private var fittedBody: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                cell(for: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    private var scrollableBody: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        cell(for: day)
                            .frame(width: 52)
                            .id(day)
                    }
                }
                // Leading/trailing inset matches the surrounding 24pt
                // content gutter so the first/last cell rests inside
                // the same column as the title and body — even though
                // the scroll container itself spans edge to edge.
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
            .onAppear { center(on: selectedDay, proxy: proxy, animated: false) }
            .onChange(of: selectedDay) { _, newValue in
                center(on: newValue, proxy: proxy, animated: true)
            }
        }
    }

    private func cell(for day: Date) -> some View {
        let isSelected = Self.cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = Self.cal.isDateInToday(day)
        let active = activityFor(day)
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedDay = Self.cal.startOfDay(for: day)
            }
        } label: {
            VStack(spacing: 4) {
                Text(Self.weekdayFormatter.string(from: day))
                    .font(Theme.caption().weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? Theme.primaryText : Theme.secondaryText
                    )
                Text(Self.dayFormatter.string(from: day))
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected ? Theme.primaryText : Theme.secondaryText.opacity(0.85)
                    )
                Circle()
                    .fill(active ? Theme.primaryText : Color.clear)
                    .frame(width: 4, height: 4)
                    .opacity(active ? (isSelected ? 1.0 : 0.6) : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Theme.primaryText.opacity(0.12))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Theme.glassStroke, lineWidth: 1)
                        )
                } else if isToday {
                    Capsule(style: .continuous)
                        .stroke(Theme.glassStroke.opacity(0.6), lineWidth: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day, isSelected: isSelected, isToday: isToday, active: active))
    }

    private func center(on day: Date, proxy: ScrollViewProxy, animated: Bool) {
        let anchor = Self.cal.startOfDay(for: day)
        if animated {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) {
                proxy.scrollTo(anchor, anchor: .center)
            }
        } else {
            proxy.scrollTo(anchor, anchor: .center)
        }
    }

    private func accessibilityLabel(for day: Date, isSelected: Bool, isToday: Bool, active: Bool) -> String {
        let dateString = Self.accessibilityFormatter.string(from: day)
        var parts: [String] = [dateString]
        if isToday { parts.append("today") }
        if active { parts.append("has activity") }
        if isSelected { parts.append("selected") }
        return parts.joined(separator: ", ")
    }

    private static let weekdayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE" // single-letter weekday
        return fmt
    }()

    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt
    }()

    private static let accessibilityFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt
    }()
}
