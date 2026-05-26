import SwiftUI
import TayaIntelligence

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
            sourceGlyph
            VStack(alignment: .leading, spacing: 2) {
                Text(moment.title)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(timeLabel)
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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

    @ViewBuilder
    private var sourceGlyph: some View {
        switch moment.kind {
        case .note:
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 22, alignment: .center)
        case .journal:
            // Journals get their own surface on Home; this is here for safety.
            Image(systemName: "book.closed")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 22, alignment: .center)
        case .voice:
            switch moment.source {
            case .necklace:
                Image(systemName: "circle.dotted.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(TayaColors.skyBlue)
                    .frame(width: 22, alignment: .center)
            case .phone:
                Image(systemName: "iphone")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 22, alignment: .center)
            }
        }
    }
}
