import SwiftUI

/// One "Resurfaced" card — an older moment surfaced for a second look.
/// Visually slightly richer than the Recently captured rows: shows the
/// polished summary and a reason / age hint.
struct ResurfacedCard: View {
    let moment: Moment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.accent)
                Text(reason)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(moment.title)
                .font(Theme.titleS())
                .foregroundStyle(Theme.primaryText)

            Text(moment.polishedSummary)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reason: String {
        "Resurfaced · \(RelativeDay.label(from: moment.createdAt))"
    }
}
