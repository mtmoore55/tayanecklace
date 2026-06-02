import SwiftUI

/// Card used to render a journal entry. The carousel style is the fixed
/// 220×220 tile that appears on Home; the list style is full-width with
/// no inner timestamp — callers render the timestamp as an eyebrow above
/// the card in list contexts (e.g. the "See all" sheet).
struct JournalCard: View {
    enum Style { case carousel, list }

    let moment: Moment
    var style: Style = .carousel

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
                .mask(textMask)

            if style == .carousel {
                Text(timeLabel)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(16)
        .modifier(JournalCardFrame(style: style))
        .tayaGlassCard(
            in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
        )
    }

    @ViewBuilder
    private var textMask: some View {
        switch style {
        case .carousel:
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black, location: 0.75),
                    .init(color: .black.opacity(0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .list:
            Color.black
        }
    }

    var timeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(moment.createdAt) {
            return moment.createdAt.formatted(date: .omitted, time: .shortened)
        }
        return RelativeDay.label(from: moment.createdAt)
    }
}

private struct JournalCardFrame: ViewModifier {
    let style: JournalCard.Style

    func body(content: Content) -> some View {
        switch style {
        case .carousel:
            content.frame(
                width: JournalCard.width,
                height: JournalCard.height,
                alignment: .topLeading
            )
        case .list:
            content.frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
