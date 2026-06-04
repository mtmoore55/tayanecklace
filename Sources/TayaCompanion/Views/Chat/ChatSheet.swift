import SwiftUI

/// Bottom-sheet wrapper around the chat experience. Owns the live
/// composer (`AskCaptureBar`), the in-flight thread, and dictation state.
/// Matches the rest of the app's detail surfaces — standard `.large`
/// detent + drag indicator + swipe-down dismiss — replacing the older
/// fade-in overlay with its bespoke `×` button.
struct ChatSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// True if the sheet should start in dictation rather than focusing
    /// the text field. Set when the user taps the mic on Home's
    /// `AskCaptureBarLauncher`.
    let autoStartRecording: Bool

    @State private var draft: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var composerRecording: Bool = false
    @FocusState private var composerFocused: Bool
    @State private var presentedChat: ChatRoute?
    @State private var showChatHistory: Bool = false
    @State private var didApplyInitialState: Bool = false
    /// Thread title, generated after the first Taya response (simulated
    /// LLM call). Nil until the first exchange completes; once set, the
    /// title fades into the top of the sheet to match `ChatDetailSheet`.
    @State private var generatedTitle: String?

    // Routes for tappable entities inside Taya's structured replies.
    @State private var presentedTask: TaskRoute?
    @State private var presentedMoment: MomentRoute?
    @State private var presentedEntity: HomeDetailRoute?

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backgroundGradient.ignoresSafeArea()

            ChatSurface(
                messages: messages,
                isRecording: composerRecording,
                title: generatedTitle ?? "How can I help?",
                presentedChat: $presentedChat,
                actions: chatBubbleActions,
                onTapSuggestion: { suggestion in
                    draft = suggestion
                    submit()
                },
                onShowHistory: { showChatHistory = true }
            )

            recordingSwell

            AskCaptureBar(
                text: $draft,
                isFocused: $composerFocused,
                isRecording: $composerRecording,
                onCapture: {},
                onSubmit: { submit() },
                showsCaptureButton: false
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(isPresented: $showChatHistory) {
            ChatsTimelineSheet(onSelectChat: { chatID in
                showChatHistory = false
                // Wait for the inner sheet to finish dismissing before
                // stacking the chat detail — iOS won't present two sheets
                // owned by the same view simultaneously.
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
        .onAppear {
            guard !didApplyInitialState else { return }
            didApplyInitialState = true
            if autoStartRecording {
                composerRecording = true
            } else {
                composerFocused = true
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

    // MARK: - Chat actions

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let isFirstExchange = messages.isEmpty
        let now = Date()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            messages.append(ChatMessage(role: .user, text: trimmed, createdAt: now))
        }
        draft = ""

        let response = mockResponse(for: trimmed, store: store)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                messages.append(
                    ChatMessage(role: .taya, content: response, createdAt: Date())
                )
            }
        }

        // Simulate the title-generation LLM call: a short pause after
        // the first response lands, then the title fades into the top
        // chrome. Only fires once per thread.
        if isFirstExchange {
            let seed = trimmed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                generatedTitle = mockTitle(for: seed)
            }
        }
    }

    /// Stand-in for the real response-generation LLM call. Pattern-matches
    /// canned queries to plain narration or, when the natural answer is a
    /// set of entities, a structured `ChatContent` list that the bubble
    /// renders inline.
    private func mockResponse(for query: String, store: DataStore) -> ChatContent {
        Self.mockResponse(for: query, store: store)
    }

    static func mockResponse(for query: String, store: DataStore) -> ChatContent {
        let q = query.lowercased()
        if q.contains("plate") || q.contains("today") || q.contains("open") {
            let ids = Array(store.openTasks().prefix(4)).map(\.id)
            return .tasks(
                intro: "A few things still open on your plate —",
                ids: ids
            )
        }
        if q.contains("place") || q.contains("try") {
            let names = Array(store.places.prefix(4))
            return .places(
                intro: "Places you've mentioned wanting to try —",
                names: names
            )
        }
        if q.contains("people") || q.contains("who") {
            let ids = Array(store.people.prefix(4)).map(\.id)
            return .people(
                intro: "People you've been talking about lately —",
                ids: ids
            )
        }
        if q.contains("maya") {
            return .text("""
            Maya has been on a recommendation streak lately:

            • The Lighthouse Years by Eliza Voss — "wrecked her in a good way"
            • Tartine in SF — the morning bun
            • True Laurel in Oakland — wants to go together
            """)
        }
        if q.contains("forgotten") || q.contains("surface") {
            return .text("Sam's freelance question from a few days ago — she asked you to think with her about leaving her firm. You haven't followed up.")
        }
        return .text("Let me look across your captured moments… I'll come back with something concrete in the real flow.")
    }

    /// Stand-in for the real title-generation LLM call. Mirrors the
    /// canned subjects in `mockResponse`; everything else falls back to
    /// a lightly-cleaned echo of the first user message.
    private func mockTitle(for query: String) -> String {
        let q = query.lowercased()
        if q.contains("maya") { return "Maya's recommendations" }
        if q.contains("plate") || q.contains("today") { return "Today's plate" }
        if q.contains("place") || q.contains("try") { return "Places to try" }
        if q.contains("people") || q.contains("who") { return "People in your orbit" }
        if q.contains("forgotten") || q.contains("surface") { return "Open follow-ups" }
        if q.contains("hike") || q.contains("trail") { return "Wildcat trail notes" }
        if q.contains("sam") { return "Sam: freelance question" }
        // Generic fallback — strip common question prefixes, trim the
        // trailing `?`, cap the length so the centered title fits.
        let cleaned = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "?.!"))
        return String(cleaned.prefix(40))
    }

    // MARK: - Recording swell

    /// Soft sky-blue radial halo that blooms behind the composer when
    /// dictation is active. Ported from RootView when the composer moved
    /// into the chat sheet.
    private var recordingSwell: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
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
                .offset(y: 90)
                .opacity(composerRecording ? 1.0 : 0)
                .allowsHitTesting(false)
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: composerRecording)
        }
    }
}

/// Identifiable wrapper so RootView can present `ChatSheet` via
/// `.sheet(item:)` and pass the initial recording flag.
struct ChatSheetRoute: Identifiable, Hashable {
    let id = UUID()
    let autoStartRecording: Bool
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ChatSheet(autoStartRecording: false)
            .environment(DataStore.seeded(now: Date()))
    }
}
