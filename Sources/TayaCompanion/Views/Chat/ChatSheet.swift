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

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backgroundGradient.ignoresSafeArea()

            ChatSurface(
                messages: messages,
                isRecording: composerRecording,
                presentedChat: $presentedChat,
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
                onSubmit: { submit() }
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
