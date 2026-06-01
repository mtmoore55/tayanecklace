import SwiftUI
import TayaIntelligence

/// Bottom-anchored chat composer with an inline capture affordance. One
/// pill, two trailing buttons that swap with the text state: a chunky
/// Sky-Blue mic when the field is empty (capture is the dominant primary
/// action), an accent send-arrow when there's text to send. No visual
/// swap on focus — the same glass capsule stays in place while the
/// TextField gains the cursor.
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
            TayaLogomark(size: 22)
                .foregroundStyle(.white)

            textContent

            trailingButton
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: height)
        .tayaGlassCard(in: Capsule(style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasText)
    }

    private var textContent: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("Ask Taya anything")
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

    @ViewBuilder
    private var trailingButton: some View {
        if hasText {
            sendButton
                .transition(.scale.combined(with: .opacity))
        } else {
            micButton
                .transition(.scale.combined(with: .opacity))
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

    private var micButton: some View {
        Button(action: onCapture) {
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: trailingSize, height: trailingSize)
                .background(Circle().fill(Theme.captureFill))
                .shadow(color: Theme.captureShadow, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture a moment")
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
