import SwiftUI
import TayaIntelligence

/// Sheet that opens when the user taps the persistent "Ask Taya" bar.
/// Shows the brand orb empty state until the first message is sent;
/// then becomes a live chat thread.
struct NewChatSheet: View {
    /// Optional pre-filled draft (e.g. from a "Ask Taya about Maya" CTA).
    var initialDraft: String? = nil
    /// When true and `initialDraft` is non-empty, the draft auto-submits
    /// on appear — makes the sheet feel like the chat is already going.
    var autoSubmit: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var isFocused: Bool

    private let suggestions = [
        "What did Maya recommend?",
        "What's on my plate today?",
        "Surface something I've forgotten"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
                composer
            }
            .background(Theme.background)
            .navigationTitle("New chat")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if let initialDraft, !initialDraft.isEmpty {
                if autoSubmit {
                    submit(text: initialDraft)
                } else {
                    draft = initialDraft
                    isFocused = true
                }
            } else {
                isFocused = true
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            TayaIntelligenceOrb(state: .idle, size: 180)
                .opacity(0.95)

            Spacer(minLength: 0)

            suggestionsRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 8)
    }

    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        submit(text: suggestion)
                    } label: {
                        Text(suggestion)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(TayaColors.skyBlue.opacity(0.28))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message).id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            inputPill
            sendButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background)
    }

    private var inputPill: some View {
        TextField("Ask Taya", text: $draft, axis: .vertical)
            .lineLimit(1...4)
            .font(Theme.bodyL())
            .focused($isFocused)
            .submitLabel(.send)
            .onSubmit { submit(text: draft) }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Capsule(style: .continuous).fill(Theme.cardSurface))
            .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 1)
    }

    private var sendButton: some View {
        Button {
            submit(text: draft)
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(canSubmit ? Theme.accent : Theme.accent.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .accessibilityLabel("Send")
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Submit + mock response

    private func submit(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        messages.append(ChatMessage(role: .user, text: trimmed, createdAt: now))
        draft = ""

        // Mock Taya response after a beat — keeps the demo lively.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            messages.append(
                ChatMessage(
                    role: .taya,
                    text: mockResponse(for: trimmed),
                    createdAt: Date()
                )
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
        return "Let me look across your captured moments… I'll come back with something concrete in the real flow."
    }
}

#Preview {
    NewChatSheet()
}
