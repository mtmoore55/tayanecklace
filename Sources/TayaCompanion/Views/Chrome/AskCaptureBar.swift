import SwiftUI

/// Bottom-anchored chrome row: the chat composer pill plus a separate
/// glass `+` button for recording a moment. While the field is focused
/// the capture button drops out so the pill can take the full width
/// — the user is actively chatting, not browsing.
///
/// The pill's trailing slot has three states:
/// - mic (idle, empty field) — taps start dictation
/// - blue checkmark (recording) — taps commit, the transcript drops
///   into the field as editable text
/// - send arrow (any text in the field) — taps submit
///
/// The leading slot is the Taya logomark while idle; while recording it
/// swaps to a cancel `×` so the user can bail without committing the
/// transcript.
///
/// While recording, the text area is replaced with `TayaListeningWaveform`,
/// driven by a simulated audio level. Real mic metering will replace
/// the `simulatedAudioLevel` seam later.
struct AskCaptureBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    @Binding var isRecording: Bool
    var onCapture: () -> Void
    var onSubmit: () -> Void
    /// When `false`, the trailing `+` capture button is suppressed
    /// entirely — used inside `ChatSheet`, where capture is unrelated
    /// to the chat flow and the button shouldn't reappear after the
    /// user dismisses the keyboard or cancels dictation.
    var showsCaptureButton: Bool = true

    private let height: CGFloat = 56
    private let trailingSize: CGFloat = 44

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            chatPill
            if showsCaptureButton, !isFocused.wrappedValue, !isRecording {
                captureButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: hasText)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused.wrappedValue)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isRecording)
    }

    // MARK: - Pill

    private var chatPill: some View {
        HStack(spacing: 10) {
            leadingControl
                .transition(.opacity)

            ZStack {
                textContent
                    .opacity(isRecording ? 0 : 1)
                if isRecording {
                    listeningContent
                        .transition(.opacity)
                }
            }

            trailingControl
                .transition(.scale.combined(with: .opacity))
        }
        .padding(.leading, isRecording ? 6 : 16)
        .padding(.trailing, 6)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listeningContent: some View {
        TayaListeningWaveform(audioLevel: simulatedAudioLevel(at:))
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .allowsHitTesting(false)
    }

    // MARK: - Leading control

    @ViewBuilder
    private var leadingControl: some View {
        if isRecording {
            Button(action: cancelDictation) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: trailingSize, height: trailingSize)
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

    // MARK: - Trailing control

    @ViewBuilder
    private var trailingControl: some View {
        if isRecording {
            commitDictationButton
                .id("recording-commit")
        } else if hasText {
            sendButton
                .id("send")
        } else {
            micButton
                .id("mic")
        }
    }

    private var micButton: some View {
        Button {
            startDictation()
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

    private var commitDictationButton: some View {
        Button {
            commitDictation()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: trailingSize, height: trailingSize)
                .background(Circle().fill(TayaColors.skyBlue))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop dictation")
    }

    private var sendButton: some View {
        Button {
            Haptics.commit()
            onSubmit()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: trailingSize, height: trailingSize)
                .background(Circle().fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send")
    }

    // MARK: - Capture button

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

    // MARK: - Dictation

    private func startDictation() {
        Haptics.tap()
        isRecording = true
        // Drop focus while recording — keyboard is irrelevant and would
        // fight the waveform for vertical real estate.
        isFocused.wrappedValue = false
    }

    private func commitDictation() {
        Haptics.commit()
        isRecording = false
        // Demo seam: real STT pipeline lands here. For now drop a
        // plausible transcript so the surrounding UI states (send arrow
        // appearing, etc.) flow correctly in design review.
        if text.isEmpty {
            text = "What did Maya recommend?"
        }
        isFocused.wrappedValue = true
    }

    /// Abort dictation without committing — drop the in-flight transcript
    /// and leave the user where they were before tapping the mic.
    private func cancelDictation() {
        Haptics.tap()
        isRecording = false
        // Don't refocus — if the user kicked off dictation from Home,
        // refocusing would yank them into the chat surface unintentionally.
    }

    /// Slow, smooth 0…~0.6 amplitude — matches the orb's "breathing
    /// with you" cadence rather than reacting to every syllable. Mirrors
    /// `CaptureSheet.simulatedAudioLevel` so both surfaces feel the
    /// same when real mic metering replaces this seam.
    private func simulatedAudioLevel(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let a = 0.55 + 0.30 * sin(t * 0.9)
        let b = 0.12 * sin(t * 2.0 + 1.2)
        return max(0, min(0.6, a + b - 0.20))
    }
}

#Preview {
    struct Wrapper: View {
        @State var text: String = ""
        @State var isRecording: Bool = false
        @FocusState var focused: Bool
        var body: some View {
            ZStack(alignment: .bottom) {
                Theme.backgroundGradient.ignoresSafeArea()
                AskCaptureBar(
                    text: $text,
                    isFocused: $focused,
                    isRecording: $isRecording,
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
