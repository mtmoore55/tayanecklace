import SwiftUI

/// Compact card used in the 2-column Notes grid on Home. Same chrome as
/// `JournalCard` but sized for short typed captures rather than long-form
/// prose.
struct NoteCard: View {
    let moment: Moment

    static let height: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(moment.rawTranscript)
                .font(Theme.bodyM())
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.leading)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Text(timeLabel)
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .topLeading)
        .tayaGlassCard(
            in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
        )
    }

    private var timeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(moment.createdAt) {
            return moment.createdAt.formatted(date: .omitted, time: .shortened)
        }
        return RelativeDay.label(from: moment.createdAt)
    }
}
