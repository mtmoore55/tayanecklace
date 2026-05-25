import SwiftUI
import TayaIntelligence

/// Persistent bottom composer: a wide "Ask Taya" text-field pill plus a
/// circular "+" button that opens an action sheet. Lives in the safe-area
/// bottom inset of `RootView` so it's visible on every page.
struct AskTayaComposer: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var onPlusTap: () -> Void

    @FocusState private var isFocused: Bool

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
        HStack(spacing: 8) {
            TextField("Ask Taya", text: $text)
                .font(Theme.body())
                .foregroundStyle(Theme.primaryText)
                .tint(Theme.accent)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit { onSubmit() }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.cardSurface)
        )
        .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
    }

    private var plusButton: some View {
        Button(action: onPlusTap) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TayaColors.oxfordBlue)
                .frame(width: 48, height: 48)
                .background(
                    Circle().fill(TayaColors.skyBlue.opacity(0.35))
                )
                .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add")
    }
}

private struct AskTayaComposerPreview: View {
    @State private var text = ""
    var body: some View {
        VStack {
            Spacer()
            AskTayaComposer(
                text: $text,
                onSubmit: {},
                onPlusTap: {}
            )
        }
        .background(Theme.background)
    }
}

#Preview {
    AskTayaComposerPreview()
}
