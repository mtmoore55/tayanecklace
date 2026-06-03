import SwiftUI

/// "See all chats" sheet presented from Home's Chats section. Mirrors the
/// shape of `MomentsView` / `TasksView` when they're presented from Home —
/// brand gradient background, large detent, Done button. Row tap routes
/// back through the parent via `onSelectChat` so the chat detail can be
/// stacked from Home rather than from this sheet (iOS won't stack two
/// sheets owned by the same view).
struct ChatsTimelineSheet: View {
    var onSelectChat: (Chat.ID) -> Void

    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Past Chats")
                    .font(Theme.greeting())
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PastChatsList(chats: store.chatsSortedByRecency, onTap: onSelectChat)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
