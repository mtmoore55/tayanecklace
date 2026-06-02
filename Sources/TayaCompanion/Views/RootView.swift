import SwiftUI

public struct RootView: View {
    @Environment(DataStore.self) private var store
    @State private var showSplash: Bool = true
    @State private var ambient: AmbientState = AmbientState(
        userInitial: "E",
        necklaceBattery: 72,
        weather: .sunny,
        isNight: AmbientState.isCurrentlyNight()
    )

    // Chat state lives here so it survives the Home ↔ Chat transition
    // and so the AskCaptureBar — which is the shared composer — can drive
    // it directly without involving a sheet/cover.
    @State private var draft: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var presentedChat: ChatRoute?
    @State private var showChatHistory: Bool = false
    @FocusState private var composerFocused: Bool

    // Mic on the AskCaptureBar presents this — capture is otherwise
    // detached from the chat flow.
    @State private var showCaptureSheet: Bool = false

    // User-chosen colorway. `auto` follows time-of-day; set from the
    // Profile sheet. Drives `preferredColorScheme` below.
    @State private var appearance: AppearanceMode = .auto

    // Which lens the Home Mirror presents. Set from the Profile sheet;
    // a preview control for now (see `MirrorLens`).
    @State private var mirrorLens: MirrorLens = .reflection

    /// Chat is active when the composer is focused (the user has tapped
    /// in to type) or when there's an in-flight conversation. Both states
    /// fade Home out and bring the chat surface in.
    private var isChatActive: Bool {
        composerFocused || !messages.isEmpty || showChatHistory
    }

    public init() {
        AppFonts.register()
    }

    public var body: some View {
        ZStack {
            // Big blue gradient sits behind everything. Pages should be
            // transparent so it shows through.
            Theme.backgroundGradient
                .ignoresSafeArea()

            mainContent

            if showSplash {
                SplashView(onFinish: {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        showSplash = false
                    }
                })
                .transition(.opacity)
            }
        }
        // Appearance preference (Auto follows time-of-day) drives the
        // colorway. Dynamic Theme tokens follow.
        .preferredColorScheme(appearance.colorScheme(isNight: ambient.isNight))
        .task {
            // First-launch sync demo. The sync state flows through the
            // inline necklace card on Home (battery → rotating orb).
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.4)) {
                ambient.sync = .syncing(current: 1, total: 2)
            }
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.25)) {
                ambient.sync = .syncing(current: 2, total: 2)
            }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeInOut(duration: 0.4)) {
                ambient.sync = .idle
                store.appendSyncedContent()
            }
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Page surface — Home when idle, the chat content when the
            // composer is active or there's a conversation in flight. The
            // shared AskCaptureBar below stays put through the transition.
            ZStack {
                if isChatActive {
                    ChatSurface(
                        messages: messages,
                        presentedChat: $presentedChat,
                        onTapSuggestion: { suggestion in
                            draft = suggestion
                            submit()
                        },
                        onShowHistory: { showChatHistory = true },
                        onDismiss: { dismissChat() }
                    )
                    .transition(.opacity)
                } else {
                    HomeView(ambient: ambient, appearance: $appearance, mirrorLens: $mirrorLens)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isChatActive)

            gradientVeil

            AskCaptureBar(
                text: $draft,
                isFocused: $composerFocused,
                onCapture: { showCaptureSheet = true },
                onSubmit: { submit() }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $showCaptureSheet) { CaptureSheet() }
        .sheet(isPresented: $showChatHistory) {
            ChatsTimelineSheet(onSelectChat: { chatID in
                showChatHistory = false
                // Wait for the sheet to finish dismissing before stacking
                // the chat detail — iOS won't present two sheets owned by
                // the same view simultaneously.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    presentedChat = ChatRoute(id: chatID)
                }
            })
            .environment(store)
            .presentationDetents([.large])
            .presentationBackground(Theme.backgroundGradient)
        }
        .sheet(item: $presentedChat) { route in
            ChatDetailSheet(chatID: route.id).environment(store)
        }
        .tint(Theme.accent)
    }

    // MARK: - Chat actions

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func dismissChat() {
        composerFocused = false
        draft = ""
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            messages = []
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

    // MARK: - Gradient veil

    /// A copy of the page gradient overlaid at the bottom, masked to
    /// fade in over ~180pt. Same `Theme.backgroundGradient` rendered
    /// with `.ignoresSafeArea()`, so every pixel matches the bg behind
    /// it — visually it just *is* the gradient. Hides page content that
    /// would otherwise scroll up through the AskCaptureBar area.
    private var gradientVeil: some View {
        Theme.backgroundGradient
            .ignoresSafeArea()
            .mask(
                VStack(spacing: 0) {
                    Color.clear
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.black, location: 0.45),
                            .init(color: Color.black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                }
                .ignoresSafeArea()
            )
            .allowsHitTesting(false)
    }
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
