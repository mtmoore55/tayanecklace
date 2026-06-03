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
    @State private var composerRecording: Bool = false
    @FocusState private var composerFocused: Bool
    /// Latches true the moment the user engages the chat composer
    /// (focuses it). Stays true through dictation (which drops focus)
    /// so the chat surface doesn't snap back to Home mid-flow. Cleared
    /// only by `dismissChat()`.
    @State private var chatSessionActive: Bool = false

    // Mic on the AskCaptureBar presents this — capture is otherwise
    // detached from the chat flow.
    @State private var showCaptureSheet: Bool = false

    // User-chosen colorway. `auto` follows time-of-day; set from the
    // Profile sheet. Drives `preferredColorScheme` below.
    @State private var appearance: AppearanceMode = .auto

    // Which lens the Home Mirror presents. Set from the Profile sheet;
    // a preview control for now (see `MirrorLens`).
    @State private var mirrorLens: MirrorLens = .reflection

    /// Chat is active when the user has explicitly engaged it — focused
    /// the composer (latched by `chatSessionActive`), has an in-flight
    /// thread, or opened history. Dictation by itself doesn't activate
    /// chat: tapping the mic from Home should leave Home in place and
    /// only morph the composer.
    private var isChatActive: Bool {
        chatSessionActive || !messages.isEmpty || showChatHistory
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
                        isRecording: composerRecording,
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
            recordingSwell

            AskCaptureBar(
                text: $draft,
                isFocused: $composerFocused,
                isRecording: $composerRecording,
                onCapture: { showCaptureSheet = true },
                onSubmit: { submit() }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .onChange(of: composerFocused) { _, focused in
            if focused { chatSessionActive = true }
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
        composerRecording = false
        chatSessionActive = false
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

    // MARK: - Recording swell

    /// Soft sky-blue radial halo that blooms behind the composer when
    /// dictation is active. Fades in as the user starts recording,
    /// gently breathes while it's running, and shrinks back to nothing
    /// when dictation ends. Sits between the gradient veil and the
    /// AskCaptureBar so it reads as the composer "lighting up" rather
    /// than as page chrome.
    private var recordingSwell: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Slow, ~5s period breathing.
            let pulse = 0.94 + 0.06 * sin(t * 1.25)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            TayaColors.skyBlue.opacity(0.7),
                            TayaColors.skyBlue.opacity(0.22),
                            TayaColors.skyBlue.opacity(0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 180
                    )
                )
                .frame(width: 420, height: 260)
                .blur(radius: 36)
                .scaleEffect(composerRecording ? pulse : 0.45)
                // Push the frame down so the visual center sits roughly
                // behind (and just above) the composer pill instead of
                // floating in the middle of the page.
                .offset(y: 90)
                .opacity(composerRecording ? 1.0 : 0)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: composerRecording)
        }
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
