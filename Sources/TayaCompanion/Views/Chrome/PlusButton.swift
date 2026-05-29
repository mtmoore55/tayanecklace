import SwiftUI
import TayaIntelligence

/// Circular action button at the right of the bottom nav row. Uses the
/// app's strong-glass recipe so it reads as part of the same glass UI
/// system as the selected nav capsule and the necklace pill — not as a
/// punched-in solid white button. The plus glyph is the dynamic
/// accent so it follows the same dark-in-light / white-in-dark
/// behavior as the nav icons.
struct PlusButton: View {
    var onCapture: () -> Void
    var onAddNote: () -> Void
    var onAddTask: () -> Void

    private let size: CGFloat = 64

    // The glass material lives outside the Menu's label. iOS 26 animates
    // the Menu's label view into and out of its popover; if the glass
    // sits inside the label, the interactive material is torn down on
    // present and takes ~1–2s to re-materialize after dismiss. Keeping
    // it as a sibling means the open/close animation never touches the
    // glass, so the circle is fully visible the instant the menu closes.
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: size, height: size)
                .tayaGlass(in: Circle(), tint: Theme.glassChromeTint, interactive: true)
                .allowsHitTesting(false)

            Menu {
                Button {
                    onCapture()
                } label: {
                    Label("Capture a moment", systemImage: "sparkles")
                }
                Button {
                    onAddTask()
                } label: {
                    Label("Add a task", systemImage: "checklist")
                }
                Button {
                    onAddNote()
                } label: {
                    Label("Add a note manually", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: size, height: size)
                    .contentShape(Circle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Add")
    }
}

#Preview {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        PlusButton(onCapture: {}, onAddNote: {}, onAddTask: {})
    }
}
