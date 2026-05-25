import SwiftUI
import TayaIntelligence

struct ChatView: View {
    @Environment(\.gesturePhase) private var gesturePhase

    private let messages: [ChatMessage] = [
        .init(role: .user, text: "What did Maya recommend?"),
        .init(role: .taya, text: "Maya gave you three recommendations in the last few days:\n\n• The Lighthouse Years by Eliza Voss — she said it \"wrecked her in a good way\"\n• Tartine in SF — raved about the morning bun\n• True Laurel in Oakland — wants to go together"),
        .init(role: .user, text: "Anything I haven't acted on yet?"),
        .init(role: .taya, text: "Two open tasks tied to Maya's recs:\n\n• Pick up The Lighthouse Years (from Wed)\n• Try True Laurel cocktail bar (from yesterday)\n\nThe Tartine idea is captured but no task yet."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                eyebrow("Today")
                ForEach(messages) { message in
                    ChatBubble(message: message)
                }
                emptyHint
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, Theme.pageContentBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(Theme.eyebrow())
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryText)
    }

    private var emptyHint: some View {
        Text("Type below to ask anything about your captured moments.")
            .font(Theme.caption())
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String

    enum Role { case user, taya }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            switch message.role {
            case .user:
                Spacer(minLength: 40)
                userBubble
            case .taya:
                tayaBubble
                Spacer(minLength: 40)
            }
        }
    }

    private var userBubble: some View {
        Text(message.text)
            .font(Theme.body())
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(TayaColors.oxfordBlue)
            )
    }

    private var tayaBubble: some View {
        Text(message.text)
            .font(Theme.body())
            .foregroundStyle(Theme.primaryText)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.cardSurface)
            )
            .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 1)
    }
}

#Preview {
    ChatView()
        .environment(DataStore.seeded(now: Date()))
}
