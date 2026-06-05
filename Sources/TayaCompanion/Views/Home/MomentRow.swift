import SwiftUI

/// Compact moment row for the "Recently captured" section. Tappable; the
/// surrounding container wraps it in a NavigationLink to the source moment.
struct MomentRow: View {
    let moment: Moment
    var timeFormat: TimeFormat = .relative

    enum TimeFormat {
        /// "today" → clock time; otherwise "yesterday" / "from Sat" / "Mar 12".
        case relative
        /// Always the clock time. Use when an outer section header already
        /// disambiguates the day (e.g. grouped Moments view).
        case timeOnly
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(moment.title)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
            if moment.syncStatus == .pending {
                pendingBadge
            }
            Spacer(minLength: 8)
            Text(timeLabel)
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var pendingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
            Text("Pending")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(TayaColors.warningAmber)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(TayaColors.warningAmber.opacity(0.15))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(TayaColors.warningAmber.opacity(0.45), lineWidth: 0.75)
        )
        .accessibilityLabel("Pending sync")
    }

    private var timeLabel: String {
        switch timeFormat {
        case .timeOnly:
            return moment.createdAt.formatted(date: .omitted, time: .shortened)
        case .relative:
            let cal = Calendar.current
            if cal.isDateInToday(moment.createdAt) {
                return moment.createdAt.formatted(date: .omitted, time: .shortened)
            }
            return RelativeDay.label(from: moment.createdAt)
        }
    }
}
