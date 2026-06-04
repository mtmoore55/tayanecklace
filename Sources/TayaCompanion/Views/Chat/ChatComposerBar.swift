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
    @State private var recorder = DictationRecorder()
    /// Text already in the field when dictation started. Live transcript
    /// is appended onto this base, so existing user input isn't clobbered
    /// and cancel can restore cleanly.
    @State private var preDictationText: String = ""

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
        // Drive the recorder lifecycle off isRecording's identity rather
        // than .onChange — .task(id:) fires on initial mount, which we
        // need if the composer ever appears already in recording state.
        .task(id: isRecording) {
            if isRecording {
                recorder.onTranscript = { next in
                    Task { @MainActor in
                        guard isRecording else { return }
                        applyTranscript(next)
                    }
                }
                recorder.onError = { _ in
                    Task { @MainActor in
                        // Permission denied / engine refused: drop the
                        // recording chrome cleanly rather than stranding
                        // the user in a waveform that will never react.
                        isRecording = false
                        text = preDictationText
                        isFocused.wrappedValue = true
                    }
                }
                await recorder.start()
                // Close the race where the host's `isRecording` flipped
                // back to false during the permission/audio-session await
                // — Swift's structured cancellation doesn't interrupt
                // those awaits, so the engine may still have come up.
                // Tear it back down so the orange-dot/UI states stay in
                // sync.
                if !isRecording && recorder.isRecording {
                    recorder.cancel()
                }
            } else if recorder.isRecording {
                recorder.cancel()
            }
        }
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
        TayaListeningWaveform(audioLevel: { _ in recorder.level })
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
        isFocused.wrappedValue = false
        preDictationText = text
        // Flipping isRecording is the single seam — .task(id:) above
        // owns recorder.start()/cancel() so user taps and any external
        // auto-start path converge here.
        isRecording = true
    }

    private func commitDictation() {
        Haptics.commit()
        // Drain final partials directly; .task's else branch is a no-op
        // once the recorder has already stopped itself.
        recorder.stop()
        isRecording = false
        isFocused.wrappedValue = true
    }

    private func cancelDictation() {
        Haptics.tap()
        text = preDictationText
        isRecording = false
    }

    /// Combine the in-flight transcript with whatever the user had typed
    /// before tapping the mic. Empty preface → just the transcript;
    /// otherwise a single space joins them so dictated speech doesn't
    /// run into existing text.
    private func applyTranscript(_ next: String) {
        guard !next.isEmpty else { return }
        if preDictationText.isEmpty {
            text = next
        } else {
            text = preDictationText + " " + next
        }
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
