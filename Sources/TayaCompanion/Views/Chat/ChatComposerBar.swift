import SwiftUI
import TayaIntelligence

/// The chat composer pill. Same `tayaGlassCard` capsule as the past-chats
/// card it sits beneath, leading `TayaLogomark` in white. Two modes:
///
/// - **Browsing** — read-only "Ask anything" placeholder; tap to activate.
/// - **Active** — focused `TextField`. The send arrow scales in inside the
///   trailing edge once there's something to send.
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

    private let height: CGFloat = 52

    var body: some View {
        HStack(spacing: 10) {
            TayaLogomark(size: 22)
                .foregroundStyle(.white)

            content

            if isActive {
                sendButton
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, isActive ? 6 : 18)
        .padding(.vertical, 9)
        .frame(minHeight: height)
        .tayaGlassCard(in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            if !isActive {
                onActivate()
            } else if !isFocused.wrappedValue {
                isFocused.wrappedValue = true
            }
        }
        .accessibilityElement(children: isActive ? .contain : .ignore)
        .accessibilityLabel(isActive ? Text("") : Text("Ask anything"))
        .accessibilityHint(isActive ? Text("") : Text("Opens a new chat"))
        .accessibilityAddTraits(isActive ? [] : .isButton)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: canSubmit)
    }

    @ViewBuilder
    private var content: some View {
        if isActive {
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
        } else {
            HStack(spacing: 0) {
                Text("Ask anything")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 0)
            }
        }
    }

    private var sendButton: some View {
        Button(action: onSubmit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.accent.opacity(canSubmit ? 1.0 : 0.4)))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .transition(.scale.combined(with: .opacity))
        .accessibilityLabel("Send")
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
