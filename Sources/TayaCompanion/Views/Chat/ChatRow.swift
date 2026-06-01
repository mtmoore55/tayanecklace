import SwiftUI

/// One line in a past-chats list — title + preview + relative day. Shared
/// by anywhere we surface past chats (the history sheet today; reusable
/// from other places that might want a chat list later).
struct ChatRow: View {
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
