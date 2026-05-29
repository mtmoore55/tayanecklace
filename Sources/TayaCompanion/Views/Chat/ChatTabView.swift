import SwiftUI
import TayaIntelligence

/// Chat tab. Two modes:
///
/// - **Browsing** — the default. "Chat" header, "Past chats" label, and a
///   scrollable list of prior chats. The composer pill sits at the bottom
///   as a tap-to-activate surface.
///
/// - **Active** — the composer is focused (keyboard up, send arrow visible
///   inline when there's text), and the body above it is either the three
///   glass starter cards (no messages yet) or the live message thread.
///   A small glass chevron-down sits top-right as the dismiss affordance;
///   tapping the Chat tab icon also dismisses.
///
/// Returning to the Chat tab always lands on browsing — any ephemeral
/// active conversation is reset when the user leaves (driven from
/// `RootView`, which bumps `resetToken` on selection change).
struct ChatTabView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase

    @State private var presentedChat: ChatRoute?
    @State private var mode: Mode = .browsing
    @State private var draft: String = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var isFocused: Bool

    /// Bumped by `RootView` when the Chat tab is tapped, or when the user
    /// swipes away. Resets to browsing and clears ephemeral chat state.
    var resetToken: Int = 0

    enum Mode { case browsing, active }

    private static let scrollTopID = "chat-scroll-top"

    private let suggestions: [StarterSuggestion] = [
        .init(text: "What did Maya recommend?"),
        .init(text: "What's on my plate today?"),
        .init(text: "Something I've been forgetting"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                bodyContent
                composerSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if mode == .active {
                dismissButton
                    .padding(.top, Theme.pageContentTopInset)
                    .padding(.trailing, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .preference(key: ChatActivePreferenceKey.self, value: mode == .active)
        .simultaneousGesture(pullDownDismissGesture, including: mode == .active ? .all : .subviews)
        .onChange(of: resetToken) { _, _ in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                dismissChat()
            }
        }
        .sheet(item: $presentedChat) { route in
            ChatDetailSheet(chatID: route.id)
                .environment(store)
        }
    }

    /// Sheet-style swipe-down dismiss. Runs simultaneously with the inner
    /// ScrollView so normal message scrolling still works — we only act
    /// on `onEnded` if the gesture clears a generous threshold and the
    /// predicted endpoint is well below the start, so an over-scroll
    /// bounce at the top of the message list doesn't accidentally
    /// dismiss.
    private var pullDownDismissGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard mode == .active else { return }
                let dy = value.translation.height
                let predicted = value.predictedEndTranslation.height
                if dy > 120 && predicted > 180 && abs(value.translation.width) < dy {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        dismissChat()
                    }
                }
            }
    }

    // MARK: - Body content per mode

    @ViewBuilder
    private var bodyContent: some View {
        switch mode {
        case .browsing:
            browsingScroll
                .transition(.opacity)
        case .active:
            if messages.isEmpty {
                suggestionsBody
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                messagesBody
                    .transition(.opacity)
            }
        }
    }

    private var browsingScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Chat")
                        .font(Theme.greeting())
                        .foregroundStyle(Theme.primaryText)

                    Text("Past chats")
                        .font(Theme.micro())
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 6)

                    history
                }
                .padding(.horizontal, 20)
                .padding(.top, Theme.pageContentTopInset)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(Self.scrollTopID)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollDisabled(gesturePhase == .horizontalSwipe)
            .onChange(of: resetToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(Self.scrollTopID, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        let chats = store.chatsSortedByRecency
        if chats.isEmpty {
            Card {
                Text("No chats yet. Ask Taya anything to start one.")
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
                                .overlay(Theme.cardStroke.opacity(0.4))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Active state bodies

    /// Suggestions read as Taya's voice — three centered brand-serif
    /// prompts under a small "Or ask…" framing label, no containers, no
    /// icons. The composer pill below is the only "interactive shape"
    /// on screen, so the suggestions feel offered, not menu'd.
    private var suggestionsBody: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Text("Or ask…")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.primaryText.opacity(0.55))

            VStack(spacing: 24) {
                ForEach(suggestions) { suggestion in
                    Button {
                        submit(text: suggestion.text)
                    } label: {
                        Text(suggestion.text)
                            .font(.custom("Aguila-Medium", size: 22))
                            .foregroundStyle(Theme.primaryText.opacity(0.88))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SuggestionLineButtonStyle())
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, Theme.pageContentTopInset + 56)
        .padding(.bottom, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var messagesBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message).id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, Theme.pageContentTopInset + 56)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Composer + dismiss

    /// Composer pill. Browsing → fixed-width (304pt) to read as
    /// "anchored to the past-chats card above". Active → expands to fill
    /// the screen width so it reads as the writing surface. Bottom inset
    /// tightens when active (no nav row underneath; keyboard handles
    /// the rest via SwiftUI's safe-area handling).
    private var composerSection: some View {
        ChatComposerBar(
            text: $draft,
            isActive: mode == .active,
            isFocused: $isFocused,
            onActivate: { activate() },
            onSubmit: { submit(text: draft) }
        )
        .frame(maxWidth: mode == .active ? .infinity : Theme.bottomChromeRowWidth)
        .padding(.horizontal, mode == .active ? 20 : 0)
        .frame(maxWidth: .infinity)
        .padding(.bottom, mode == .active ? 12 : Theme.chatComposerBottomInset)
    }

    private var dismissButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                dismissChat()
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close chat")
    }

    // MARK: - State transitions

    private func activate() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            mode = .active
        }
        // Defer focus so the TextField is mounted by the time we ask for it.
        DispatchQueue.main.async {
            isFocused = true
        }
    }

    private func dismissChat() {
        mode = .browsing
        messages = []
        draft = ""
        isFocused = false
    }

    // MARK: - Submit + mock response

    private func submit(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            messages.append(ChatMessage(role: .user, text: trimmed, createdAt: now))
        }
        draft = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                messages.append(
                    ChatMessage(
                        role: .taya,
                        text: mockResponse(for: trimmed),
                        createdAt: Date()
                    )
                )
            }
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
        return "Let me look across your captured moments… I'll come back with something concrete in the real flow."
    }
}

/// Identifiable wrapper for sheet presentation by chat ID.
struct ChatRoute: Identifiable, Hashable {
    let id: Chat.ID
}

/// Set by `ChatTabView` while in `.active` mode. `RootView` reads this
/// to fade out the bottom chrome (nav row + Plus button) so the active
/// chat surface has the screen to itself.
struct ChatActivePreferenceKey: PreferenceKey {
    static let defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

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

private struct StarterSuggestion: Identifiable {
    let id = UUID()
    let text: String
}

private struct SuggestionLineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ChatTabView()
        .background(Theme.backgroundGradient)
        .environment(DataStore.seeded(now: Date()))
}
