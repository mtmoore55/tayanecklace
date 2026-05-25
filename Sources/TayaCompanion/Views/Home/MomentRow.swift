import SwiftUI
import TayaIntelligence

/// Compact moment row for the "Recently captured" section. Tappable; the
/// surrounding container wraps it in a NavigationLink to the source moment.
struct MomentRow: View {
    let moment: Moment

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            sourceGlyph
            VStack(alignment: .leading, spacing: 2) {
                Text(moment.title)
                    .font(Theme.body())
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
        let cal = Calendar.current
        if cal.isDateInToday(moment.createdAt) {
            return moment.createdAt.formatted(date: .omitted, time: .shortened)
        }
        return RelativeDay.label(from: moment.createdAt)
    }

    @ViewBuilder
    private var sourceGlyph: some View {
        switch moment.source {
        case .necklace:
            Image(systemName: "circle.dotted.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(TayaColors.skyBlue)
        case .phone:
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
