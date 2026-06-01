import SwiftUI
import TayaIntelligence

/// Glass card with `ChatRow` rows separated by hairline dividers. Shared
/// by the three places we render past chats: Home's "Chats" section, the
/// "See all chats" sheet, and the chat surface (when the composer is
/// active but no thread is in flight).
struct PastChatsList: View {
    let chats: [Chat]
    var onTap: (Chat.ID) -> Void

    var body: some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                ForEach(Array(chats.enumerated()), id: \.element.id) { index, chat in
                    Button {
                        onTap(chat.id)
                    } label: {
                        ChatRow(chat: chat)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < chats.count - 1 {
                        Divider()
                            .padding(.leading, 12)
                            .overlay(Theme.cardStroke.opacity(0.4))
                    }
                }
            }
        }
    }
}
