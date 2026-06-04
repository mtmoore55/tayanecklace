import SwiftUI

/// The chat content surface rendered inside `ChatSheet`. Renders one of
/// two bodies:
///
/// 1. **Messages** — the live thread once the user has sent something.
/// 2. **Starter suggestions** — the default landing while no thread is
///    active. Past chats are accessed via the rewind button in the header.
///
/// The composer is owned by `ChatSheet` (an `AskCaptureBar` pinned to the
/// sheet's bottom); this view renders only the body above it plus the
/// history button. Dismissal is the sheet's own drag-indicator + swipe,
/// matching the rest of the app's detail surfaces.
struct ChatSurface: View {
    let messages: [ChatMessage]
    let isRecording: Bool
    /// Generated thread title that fades in once Taya has "named" the
    /// chat (simulated LLM call from `ChatSheet`). Nil before that —
    /// the top row is just the trailing history button.
    let title: String?
    @Binding var presentedChat: ChatRoute?
    /// Routing callbacks for entity taps inside structured Taya replies.
    /// Defaults to no-op so non-routing callers (previews, embeds) work.
    var actions: ChatBubbleActions = ChatBubbleActions()
    var onTapSuggestion: (String) -> Void
    var onShowHistory: () -> Void

    private let suggestions: [StarterSuggestion] = [
        .init(text: "What's on my plate today?"),
        .init(text: "Places I've been hoping to try"),
        .init(text: "Something I've been forgetting"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionRow
            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Top row pinned under the drag indicator. Centered SF Pro title
    /// (when a title has been generated) with the history button at the
    /// trailing edge. Matches the chrome shape of `ChatDetailSheet` so
    /// the live chat reads as the same kind of surface once Taya has
    /// titled it.
    private var actionRow: some View {
        ZStack {
            if let title {
                Text(title)
                    .font(Theme.titleM())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 56)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .id(title)
            }
            HStack {
                Spacer()
                historyButton
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: title)
    }

    @ViewBuilder
    private var bodyContent: some View {
        // Dictation no longer blanks the body — the context the user was
        // looking at (their thread, or the suggestion landing) stays put
        // and only the composer below changes.
        if !messages.isEmpty {
            messagesBody
        } else {
            suggestionsBody
        }
    }

    private var suggestionsBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            suggestionsCluster
                .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Stacked starter pills above the composer. Capsule shape with a
    /// thin white outline instead of a glass card — the suggestion list
    /// shouldn't compete visually with the composer/chrome below it.
    private var suggestionsCluster: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(suggestions) { suggestion in
                Button {
                    onTapSuggestion(suggestion.text)
                } label: {
                    Text(suggestion.text)
                        .font(Theme.bodyM().weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(SuggestionLineButtonStyle())
            }
        }
        .padding(.horizontal, 24)
    }

    private var messagesBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message, actions: actions).id(message.id)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
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

    private var historyButton: some View {
        Button(action: onShowHistory) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Past chats")
    }
}

/// Identifiable wrapper for sheet presentation by chat ID. Lives here so
/// it survives the deletion of the old ChatTabView.
struct ChatRoute: Identifiable, Hashable {
    let id: Chat.ID
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
