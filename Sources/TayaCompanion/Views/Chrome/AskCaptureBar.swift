import SwiftUI

/// Bottom-anchored chrome row: the chat composer pill plus a separate
/// glass `+` button for recording a moment. The two functions are
/// distinct (chatting vs. capturing) so they get distinct affordances
/// side by side. Inside the pill, the trailing slot stays empty until
/// the user types something — then a send arrow scales in.
struct AskCaptureBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onCapture: () -> Void
    var onSubmit: () -> Void

    private let height: CGFloat = 56
    private let trailingSize: CGFloat = 44

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            chatPill
            captureButton
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasText)
    }

    private var chatPill: some View {
        HStack(spacing: 10) {
            TayaLogomark(size: 22)
                .foregroundStyle(.white)

            textContent

            if hasText {
                sendButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, hasText ? 6 : 18)
        .padding(.vertical, 6)
        .frame(minHeight: height)
        .tayaGlassCard(in: Capsule(style: .continuous))
    }

    private var textContent: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("Ask anything")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText.opacity(0.65))
                    .allowsHitTesting(false)
            }
            TextField("", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(Theme.bodyL())
                .focused(isFocused)
                .submitLabel(.send)
                .onSubmit(onSubmit)
                .foregroundStyle(Theme.primaryText)
                .tint(.white)
        }
    }

    private var sendButton: some View {
        Button(action: onSubmit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: trailingSize, height: trailingSize)
                .background(Circle().fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send")
    }

    private var captureButton: some View {
        Button(action: onCapture) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: height, height: height)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record a moment")
    }
}

#Preview {
    struct Wrapper: View {
        @State var text: String = ""
        @FocusState var focused: Bool
        var body: some View {
            ZStack(alignment: .bottom) {
                Theme.backgroundGradient.ignoresSafeArea()
                AskCaptureBar(
                    text: $text,
                    isFocused: $focused,
                    onCapture: {},
                    onSubmit: {}
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
    return Wrapper()
}
