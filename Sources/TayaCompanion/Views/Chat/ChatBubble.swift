import SwiftUI

/// One message in a chat thread. User messages sit in a right-aligned
/// glass bubble; Taya replies render as plain full-width body text so
/// her responses feel like spoken narration rather than a chat reply.
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack(alignment: .top) {
                Spacer(minLength: 40)
                userBubble
            }
        case .taya:
            tayaText
        }
    }

    private var userBubble: some View {
        Text(message.text)
            .font(Theme.bodyL())
            .foregroundStyle(Theme.primaryText)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .tayaGlassCard(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }

    private var tayaText: some View {
        Text(message.text)
            .font(Theme.bodyL())
            .foregroundStyle(Theme.primaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
