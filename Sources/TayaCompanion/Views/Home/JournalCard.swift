import SwiftUI

/// Large-ish card used in the horizontal Journal carousel on Home. Shows
/// an excerpt of the entry with a soft fade-out at the bottom and the time
/// the entry was written.
struct JournalCard: View {
    let moment: Moment

    static let width: CGFloat = 220
    static let height: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(moment.rawTranscript)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.75),
                            .init(color: .black.opacity(0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(timeLabel)
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .frame(width: Self.width, height: Self.height, alignment: .topLeading)
        .background(Theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
    }

    private var timeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(moment.createdAt) {
            return moment.createdAt.formatted(date: .omitted, time: .shortened)
        }
        return RelativeDay.label(from: moment.createdAt)
    }
}
