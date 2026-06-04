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

    // Routes for tappable entities inside Taya's structured replies.
    @State private var presentedTask: TaskRoute?
    @State private var presentedMoment: MomentRoute?
    @State private var presentedEntity: HomeDetailRoute?

    var body: some View {
        VStack(spacing: 0) {
            header
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
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $presentedTask) { route in
            TaskDetailSheet(taskID: route.id).environment(store)
        }
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route).environment(store)
        }
        .sheet(item: $presentedEntity) { route in
            switch route {
            case .person(let id):
                PersonDetailSheet(personID: id).environment(store)
            case .place(let p):
                PlaceDetailSheet(place: p).environment(store)
            case .theme(let t):
                ThemeDetailSheet(theme: t).environment(store)
            }
        }
    }

    private var chatBubbleActions: ChatBubbleActions {
        ChatBubbleActions(
            onTapTask: { presentedTask = TaskRoute(id: $0) },
            onTapPerson: { presentedEntity = .person($0) },
            onTapPlace: { presentedEntity = .place($0) },
            onTapMoment: { presentedMoment = MomentRoute(ids: [$0], startID: $0) }
        )
    }

    // MARK: - Header (custom — bypasses NavigationStack so the trailing
    // ellipsis uses the same `tayaGlassCard` material as the rest of the
    // app's circular controls instead of UIKit's whiter toolbar chrome.)

    private var header: some View {
        let chat = store.chat(chatID)
        return ZStack {
            Text(chat?.title ?? "Chat")
                .font(Theme.titleM())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .padding(.horizontal, 56)
            HStack {
                Spacer()
                if let chat, !chat.messages.isEmpty {
                    overflowMenu(for: chat)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Messages

    private func messagesList(chat: Chat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(chat.messages) { message in
                        ChatBubble(message: message, actions: chatBubbleActions)
                            .id(message.id)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 36, height: 36)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
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

        let response = ChatSheet.mockResponse(for: trimmed, store: store)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            store.appendMessage(to: chatID, role: .taya, content: response)
        }
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
