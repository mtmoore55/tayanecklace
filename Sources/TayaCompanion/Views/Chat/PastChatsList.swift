import SwiftUI

/// Glass card with `ChatRow` rows separated by hairline dividers. Shared
/// by the three places we render past chats: Home's "Chats" section, the
/// "See all chats" sheet, and the chat surface (when the composer is
/// active but no thread is in flight).
struct PastChatsList: View {
    let chats: [Chat]
    var onTap: (Chat.ID) -> Void
    /// Optional swipe-to-delete handler. When supplied, each row reveals
    /// a trailing red Delete chip on swipe and fires this closure on
    /// commit — typically wired to `store.deleteChat(_:)`.
    var onDelete: ((Chat) -> Void)? = nil

    var body: some View {
        Card(padding: 0) {
            SwipeListView(
                items: chats,
                trailingActions: trailingActions
            ) { chat in
                Button {
                    onTap(chat.id)
                } label: {
                    ChatRow(chat: chat)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func trailingActions(for chat: Chat) -> [SwipeAction] {
        guard let onDelete else { return [] }
        return [
            SwipeAction(
                label: "Delete",
                systemImage: "trash",
                tint: .red,
                role: .destructive,
                action: { onDelete(chat) }
            )
        ]
    }
}
