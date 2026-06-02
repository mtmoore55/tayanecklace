import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Horizontal row of one-tap actions that sits below the content on
/// Moment, Task, and Chat detail surfaces. Same component everywhere so
/// the shape and placement are predictable; per-surface variation is
/// expressed by omitting actions (e.g. Chat is hidden on ChatDetailSheet,
/// since you're already in a chat).
///
/// Each action is a glass capsule with icon + label, matching the rest
/// of the app's glass language.
struct MomentActionsRow: View {
    /// Tapping Chat opens the host's QuickAskTayaSheet, seeded by the
    /// caller. Nil hides the button.
    var onChat: (() -> Void)? = nil
    /// Text placed on the pasteboard when Copy is tapped. Nil hides the
    /// button.
    var copyText: String? = nil
    /// Markdown payload handed to `ShareLink`. Nil hides the button.
    var shareItem: String? = nil

    @State private var didCopy: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if let onChat {
                actionButton(
                    label: "Chat",
                    systemImage: "bubble.left.and.text.bubble.right",
                    action: onChat
                )
            }
            if let copyText {
                actionButton(
                    label: didCopy ? "Copied" : "Copy",
                    systemImage: didCopy ? "checkmark" : "doc.on.doc",
                    action: { copy(copyText) }
                )
                .accessibilityLabel(didCopy ? "Copied" : "Copy")
            }
            if let shareItem {
                ShareLink(item: shareItem) {
                    actionLabel(label: "Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionLabel(label: label, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(label: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(label)
                .font(Theme.bodyM())
        }
        .foregroundStyle(Theme.primaryText)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .tayaGlassCard(in: Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                didCopy = false
            }
        }
    }
}
