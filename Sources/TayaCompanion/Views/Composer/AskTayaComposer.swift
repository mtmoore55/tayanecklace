import SwiftUI
import TayaIntelligence

/// Persistent bottom composer: a wide "Ask Taya" placeholder pill that
/// opens a new chat sheet when tapped, plus a circular "+" button with a
/// menu (Capture / Add note). The bar is *not* an inline text field —
/// typing happens inside the new-chat sheet so the experience is consistent
/// across every tab.
struct AskTayaComposer: View {
    var onOpenChat: () -> Void
    var onCapture: () -> Void
    var onAddNote: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            inputPill
            plusButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var inputPill: some View {
        Button(action: onOpenChat) {
            HStack {
                Text("Ask Taya")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Capsule(style: .continuous).fill(Theme.cardSurface))
            .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask Taya")
        .accessibilityHint("Opens a new chat")
    }

    private var plusButton: some View {
        Menu {
            Button {
                onCapture()
            } label: {
                Label("Capture a moment", systemImage: "sparkles")
            }
            Button {
                onAddNote()
            } label: {
                Label("Add a note manually", systemImage: "square.and.pencil")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(TayaColors.skyBlue.opacity(0.35))
                )
                .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
    }
}

#Preview {
    VStack {
        Spacer()
        AskTayaComposer(
            onOpenChat: {},
            onCapture: {},
            onAddNote: {}
        )
    }
    .background(Theme.background)
}
