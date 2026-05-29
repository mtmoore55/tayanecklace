import SwiftUI
import TayaIntelligence

/// One message in a chat thread. User messages are right-aligned with an
/// oxford-blue bubble; Taya responses are left-aligned in a white card.
struct ChatBubble: View {
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
            .font(Theme.bodyL())
            .foregroundStyle(Theme.onAccent)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.accent)
            )
    }

    private var tayaBubble: some View {
        Text(message.text)
            .font(Theme.bodyL())
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
