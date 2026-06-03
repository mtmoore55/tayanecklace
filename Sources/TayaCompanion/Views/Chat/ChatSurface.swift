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
    @Binding var presentedChat: ChatRoute?
    var onTapSuggestion: (String) -> Void
    var onShowHistory: () -> Void

    private let suggestions: [StarterSuggestion] = [
        .init(text: "What did Maya recommend?"),
        .init(text: "What's on my plate today?"),
        .init(text: "Something I've been forgetting"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionRow
            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Trailing-aligned action row pinned to the top of the sheet body,
    /// just below the drag indicator. Holds the past-chats rewind today;
    /// an ellipsis menu can join it once there's a thread to act on.
    private var actionRow: some View {
        HStack(spacing: 10) {
            Spacer()
            historyButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
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
            Text("Chat")
                .font(Theme.greeting())
                .foregroundStyle(Theme.primaryText)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Spacer(minLength: 0)

            suggestionsCluster
                .padding(.bottom, 80)
        }
    }

    /// Compact, keyboard-safe chip row that sits just above the composer.
    /// Replaces the previous full-page editorial stack — chips read as
    /// tappable shortcuts rather than body copy, and scroll horizontally
    /// when there are more than fit.
    private var suggestionsCluster: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
                            .tayaGlassCard(in: Capsule(style: .continuous))
                            .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(SuggestionLineButtonStyle())
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollClipDisabled()
    }

    private var messagesBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message).id(message.id)
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
