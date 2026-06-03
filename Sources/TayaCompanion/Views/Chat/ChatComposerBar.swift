import SwiftUI

/// The chat composer pill. Same `tayaGlassCard` capsule as the past-chats
/// card it sits beneath, leading `TayaLogomark` in white. Two modes:
///
/// - **Browsing** — read-only "Ask anything" placeholder; tap to activate.
/// - **Active** — focused `TextField`. Trailing slot mirrors `AskCaptureBar`:
///   mic when the field is empty, send arrow once there's text, blue
///   checkmark while dictating (with leading cancel `×`).
///
/// Geometry is invariant across modes (height + leading inset + leading
/// logomark are identical) so the pill the user tapped *is* the pill they
/// end up typing into — no morph seam.
struct ChatComposerBar: View {
    @Binding var text: String
    var isActive: Bool
    var isFocused: FocusState<Bool>.Binding
    var onActivate: () -> Void
    var onSubmit: () -> Void

    @State private var isRecording: Bool = false

    private let height: CGFloat = 52
    private let controlSize: CGFloat = 38

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            leadingControl
                .transition(.opacity)

            content

            if isActive {
                trailingControl
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, isRecording ? 6 : 16)
        .padding(.trailing, isActive ? 6 : 18)
        .padding(.vertical, 9)
        .frame(minHeight: height)
        .tayaGlassCard(in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            if !isActive {
                onActivate()
            } else if !isFocused.wrappedValue && !isRecording {
                isFocused.wrappedValue = true
            }
        }
        .accessibilityElement(children: isActive ? .contain : .ignore)
        .accessibilityLabel(isActive ? Text("") : Text("Ask anything"))
        .accessibilityHint(isActive ? Text("") : Text("Opens a new chat"))
        .accessibilityAddTraits(isActive ? [] : .isButton)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasText)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isRecording)
    }

    // MARK: - Leading control

    @ViewBuilder
    private var leadingControl: some View {
        if isRecording {
            Button(action: cancelDictation) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: controlSize, height: controlSize)
                    .tayaGlassCard(in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel dictation")
        } else {
            TayaLogomark(size: 22)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isActive {
            ZStack(alignment: .leading) {
                activeField.opacity(isRecording ? 0 : 1)
                if isRecording {
                    listeningContent
                        .transition(.opacity)
                }
            }
        } else {
            HStack(spacing: 0) {
                Text("Ask anything")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 0)
            }
        }
    }

    private var activeField: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("Reply to Taya")
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

    private var listeningContent: some View {
        TayaListeningWaveform(audioLevel: simulatedAudioLevel(at:))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .allowsHitTesting(false)
    }

    // MARK: - Trailing control

    @ViewBuilder
    private var trailingControl: some View {
        if isRecording {
            commitDictationButton.id("recording-commit")
        } else if hasText {
            sendButton.id("send")
        } else {
            micButton.id("mic")
        }
    }

    private var sendButton: some View {
        Button {
            Haptics.commit()
            onSubmit()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: controlSize, height: controlSize)
                .background(Circle().fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send")
    }

    private var micButton: some View {
        Button(action: startDictation) {
            Image(systemName: "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: controlSize, height: controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dictate")
    }

    private var commitDictationButton: some View {
        Button(action: commitDictation) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: controlSize, height: controlSize)
                .background(Circle().fill(TayaColors.skyBlue))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop dictation")
    }

    // MARK: - Dictation

    private func startDictation() {
        Haptics.tap()
        isRecording = true
        isFocused.wrappedValue = false
    }

    private func commitDictation() {
        Haptics.commit()
        isRecording = false
        // Demo seam — real STT lands here. For now drop a plausible
        // follow-up so the send-arrow state appears for design review.
        if text.isEmpty {
            text = "What else should I know?"
        }
        isFocused.wrappedValue = true
    }

    private func cancelDictation() {
        Haptics.tap()
        isRecording = false
    }

    /// Mirrors `AskCaptureBar.simulatedAudioLevel` so the waveform feels
    /// identical between the home composer and the chat composer.
    private func simulatedAudioLevel(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let a = 0.55 + 0.30 * sin(t * 0.9)
        let b = 0.12 * sin(t * 2.0 + 1.2)
        return max(0, min(0.6, a + b - 0.20))
    }
}

#Preview {
    struct Wrapper: View {
        @State var text = ""
        @State var active = false
        @FocusState var focused: Bool
        var body: some View {
            ZStack(alignment: .bottom) {
                Theme.backgroundGradient.ignoresSafeArea()
                ChatComposerBar(
                    text: $text,
                    isActive: active,
                    isFocused: $focused,
                    onActivate: { active = true },
                    onSubmit: { text = "" }
                )
                .frame(width: 304)
                .padding(.bottom, 40)
            }
        }
    }
    return Wrapper()
}
