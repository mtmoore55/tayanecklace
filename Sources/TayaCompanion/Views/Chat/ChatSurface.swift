import SwiftUI

/// The chat content surface that fades in over Home when the AskCaptureBar
/// becomes active. Renders one of two bodies:
///
/// 1. **Messages** — the live thread once the user has sent something.
/// 2. **Starter suggestions** — the default landing while no thread is
///    active. Past chats are accessed via the rewind button in the header.
///
/// The composer is owned by `AskCaptureBar` in `RootView`; this view
/// renders only the body above it, plus the header buttons.
struct ChatSurface: View {
    let messages: [ChatMessage]
    @Binding var presentedChat: ChatRoute?
    var onTapSuggestion: (String) -> Void
    var onShowHistory: () -> Void
    var onDismiss: () -> Void

    private let suggestions: [StarterSuggestion] = [
        .init(text: "What did Maya recommend?"),
        .init(text: "What's on my plate today?"),
        .init(text: "Something I've been forgetting"),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            bodyContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                historyButton
                dismissButton
            }
            .padding(.top, Theme.pageContentTopInset)
            .padding(.trailing, 20)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
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
                .padding(.horizontal, 20)
                .padding(.top, Theme.pageContentTopInset)

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
                            onTapSuggestion(suggestion.text)
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
            .padding(.bottom, 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
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

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close chat")
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
