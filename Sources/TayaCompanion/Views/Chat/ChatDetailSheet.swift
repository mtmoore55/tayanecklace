import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Full view of a chat — past messages plus a live composer at the bottom
/// so the user can continue the conversation. New messages persist back
/// into the DataStore so the Chats list reflects the updated recency.
struct ChatDetailSheet: View {
    let chatID: Chat.ID
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if let chat = store.chat(chatID) {
                        messagesList(chat: chat)
                    } else {
                        ContentUnavailableView(
                            "Chat not found",
                            systemImage: "bubble.left"
                        )
                    }
                }
                composer
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(store.chat(chatID)?.title ?? "Chat")
                        .font(Theme.titleM())
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                }
                if let chat = store.chat(chatID), !chat.messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        overflowMenu(for: chat)
                    }
                }
            }
            #if os(iOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
    }

    // MARK: - Messages

    private func messagesList(chat: Chat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(chat.messages) { message in
                        ChatBubble(message: message).id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.messages.count) {
                if let last = chat.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let last = chat.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        ChatComposerBar(
            text: $draft,
            isActive: true,
            isFocused: $isFocused,
            onActivate: {},
            onSubmit: submit
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Overflow menu (Copy / Share)

    private func overflowMenu(for chat: Chat) -> some View {
        Menu {
            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = chatPlainText(chat)
                #endif
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: chatMarkdown(chat)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
    }

    // MARK: - Copy / Share formatting

    private func chatPlainText(_ chat: Chat) -> String {
        chat.messages.map { line(for: $0) }.joined(separator: "\n\n")
    }

    private func chatMarkdown(_ chat: Chat) -> String {
        var lines: [String] = ["## \(chat.title)"]
        for message in chat.messages {
            lines.append("")
            lines.append(line(for: message))
        }
        return lines.joined(separator: "\n")
    }

    private func line(for message: ChatMessage) -> String {
        let prefix = message.role == .user ? "**You:**" : "**Taya:**"
        return "\(prefix) \(message.text)"
    }

    // MARK: - Submit + mock response

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.appendMessage(to: chatID, role: .user, text: trimmed)
        draft = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            store.appendMessage(
                to: chatID,
                role: .taya,
                text: mockResponse(for: trimmed)
            )
        }
    }

    private func mockResponse(for query: String) -> String {
        let q = query.lowercased()
        if q.contains("maya") {
            return """
            Maya has been on a recommendation streak lately:

            • The Lighthouse Years by Eliza Voss — "wrecked her in a good way"
            • Tartine in SF — the morning bun
            • True Laurel in Oakland — wants to go together
            """
        }
        if q.contains("plate") || q.contains("today") {
            return """
            Four open tasks on your plate. Dental cleaning is the only one with a deadline (end of June). The rest are open-ended.
            """
        }
        if q.contains("forgotten") || q.contains("surface") {
            return """
            Sam's freelance question from a few days ago — she asked you to think with her about leaving her firm. You haven't followed up.
            """
        }
        if q.contains("hike") || q.contains("trail") {
            return """
            Wildcat Canyon — you noted a new trailhead and the creek crossing was sharper than it looked. You wanted to bring water shoes next time.
            """
        }
        return "Let me look across your captured moments… I'll come back with something concrete in the real flow."
    }
}

#Preview {
    if let chat = DataStore.seeded(now: Date()).chats.first {
        ChatDetailSheet(chatID: chat.id)
            .environment(DataStore.seeded(now: Date()))
    } else {
        Text("No seed chats")
    }
}
