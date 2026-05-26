import SwiftUI
import TayaIntelligence

struct ChatView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedChat: ChatRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Chats")
                    .font(Theme.displayMedium())
                    .foregroundStyle(Theme.primaryText)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, Theme.pageContentBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
        .sheet(item: $presentedChat) { route in
            ChatDetailSheet(chatID: route.id)
                .environment(store)
        }
    }

    @ViewBuilder
    private var content: some View {
        let chats = store.chatsSortedByRecency
        if chats.isEmpty {
            Card {
                Text("No chats yet. Tap \"Ask Taya\" to start one.")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
            }
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(chats.enumerated()), id: \.element.id) { index, chat in
                        Button {
                            guard gesturePhase == .idle else { return }
                            presentedChat = ChatRoute(id: chat.id)
                        } label: {
                            ChatRow(chat: chat)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if index < chats.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

}

/// Single row in the chat list — title, preview, timestamp.
private struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(Theme.titleS())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                Text(chat.preview)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(RelativeDay.label(from: chat.lastMessageAt))
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

/// Identifiable wrapper for sheet presentation by chat ID.
struct ChatRoute: Identifiable, Hashable {
    let id: Chat.ID
}

#Preview {
    ChatView()
        .environment(DataStore.seeded(now: Date()))
}
