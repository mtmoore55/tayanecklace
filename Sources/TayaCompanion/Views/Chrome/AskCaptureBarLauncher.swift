import SwiftUI

/// Idle facade of `AskCaptureBar` rendered at the bottom of Home. Visually
/// matches `AskCaptureBar`'s empty state — logomark + "Ask anything"
/// placeholder + mic + capture `+` — but is non-input: tapping the pill
/// fires `onActivate`, tapping the mic fires `onMicActivate`, both of which
/// present the chat sheet. The real composer (with the focusable TextField
/// + dictation) lives inside that sheet.
struct AskCaptureBarLauncher: View {
    var onActivate: () -> Void
    var onMicActivate: () -> Void
    var onCapture: () -> Void

    private let height: CGFloat = 56
    private let trailingSize: CGFloat = 44

    var body: some View {
        HStack(spacing: 10) {
            chatPill
            captureButton
        }
    }

    private var chatPill: some View {
        HStack(spacing: 10) {
            TayaLogomark(size: 22)
                .foregroundStyle(.white)

            Text("Ask anything")
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText.opacity(0.65))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.tap()
                    onActivate()
                }

            Button {
                Haptics.tap()
                onMicActivate()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: trailingSize, height: trailingSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dictate")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: height)
        .tayaGlassCard(in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        // Catches taps on the logomark / padding that fall outside the
        // text or mic targets — same activation as tapping the placeholder.
        .onTapGesture {
            Haptics.tap()
            onActivate()
        }
        .accessibilityElement(children: .contain)
    }

    private var captureButton: some View {
        Button {
            Haptics.tap()
            onCapture()
        } label: {
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
    ZStack(alignment: .bottom) {
        Theme.backgroundGradient.ignoresSafeArea()
        AskCaptureBarLauncher(
            onActivate: {},
            onMicActivate: {},
            onCapture: {}
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}
