import SwiftUI

/// Small confirmation toast — glass capsule with a sky-blue check and a
/// short label. Bottom-anchored, auto-dismissed. Used by the inline
/// "copy" buttons on detail sections.
struct TayaToast: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TayaColors.skyBlue)
            Text(text)
                .font(Theme.bodyM())
                .foregroundStyle(Theme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .tayaGlassCard(in: Capsule(style: .continuous))
    }
}

/// Identifiable wrapper so re-triggering the same text fires a fresh
/// presentation (UUID changes even when the text repeats).
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

extension View {
    /// Bottom-anchored confirmation toast. Setting `message` triggers
    /// it; it self-dismisses after `duration` seconds.
    func tayaToast(_ message: Binding<ToastMessage?>, duration: TimeInterval = 1.6) -> some View {
        modifier(TayaToastModifier(message: message, duration: duration))
    }
}

private struct TayaToastModifier: ViewModifier {
    @Binding var message: ToastMessage?
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    TayaToast(text: message.text)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message.id) {
                            try? await Task.sleep(for: .seconds(duration))
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.message = nil
                            }
                        }
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: message?.id)
    }
}

#Preview {
    struct Wrapper: View {
        @State var toast: ToastMessage? = ToastMessage(text: "Copied")
        var body: some View {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                Button("Show toast") {
                    toast = ToastMessage(text: "Copied")
                }
                .foregroundStyle(.white)
            }
            .tayaToast($toast)
        }
    }
    return Wrapper()
}
