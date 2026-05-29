import SwiftUI
import TayaIntelligence

/// Compact "Ask Taya about X" sheet used from detail surfaces (Person /
/// Place / Theme). The user is already in a focused sub-flow, so this
/// stays presentational — auto-submits the seed query on appear, then
/// behaves like the Chat tab's active mode (live message thread + the
/// shared `ChatComposerBar` for follow-up). The Chat tab itself owns the
/// primary chat flow; this sheet is for in-context lookups.
struct QuickAskTayaSheet: View {
    var initialDraft: String

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var didSeed: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                messagesList
                composer
            }

            closeButton
                .padding(.top, 16)
                .padding(.trailing, 20)
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !didSeed else { return }
            didSeed = true
            submit(text: initialDraft)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message).id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 72)
                .padding(.bottom, 12)
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

    private var composer: some View {
        HStack {
            Spacer(minLength: 0)
            ChatComposerBar(
                text: $draft,
                isActive: true,
                isFocused: $isFocused,
                onActivate: {},
                onSubmit: { submit(text: draft) }
            )
            .frame(width: Theme.bottomChromeRowWidth)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func submit(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            messages.append(ChatMessage(role: .user, text: trimmed, createdAt: Date()))
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

#Preview {
    QuickAskTayaSheet(initialDraft: "What did Maya recommend?")
}
