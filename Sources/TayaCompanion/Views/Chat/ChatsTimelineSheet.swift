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
    @State private var showRecentlyDeleted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                Text("Past Chats")
                    .font(Theme.greeting())
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PastChatsList(
                    chats: store.chatsSortedByRecency,
                    onTap: onSelectChat,
                    onDelete: { chat in
                        withAnimation(.snappy) { store.deleteChat(chat) }
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear { store.purgeExpiredDeletedChats() }
        .sheet(isPresented: $showRecentlyDeleted) {
            RecentlyDeletedChatsSheet().environment(store)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Menu {
                Button {
                    Haptics.tap()
                    showRecentlyDeleted = true
                } label: {
                    Label("Recently deleted", systemImage: "trash.slash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .tayaGlassCard(in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("More actions")
        }
    }
}
