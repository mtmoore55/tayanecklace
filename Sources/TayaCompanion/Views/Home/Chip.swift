import SwiftUI
import TayaIntelligence

/// Pill-shaped chip used for Places and Themes on Today. Tappable; the
/// caller hooks the action.
struct Chip: View {
    let text: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(Theme.body())
                .foregroundStyle(TayaColors.oxfordBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(TayaColors.skyBlue.opacity(0.28))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping flow of chips. Falls back to a horizontal scroll on very narrow
/// screens via the adaptive grid.
struct ChipFlow: View {
    let items: [String]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items, id: \.self) { item in
                Chip(text: item)
            }
        }
    }
}
