import SwiftUI

/// Currently unused — Browse content is being folded into Today in Phase 3.
/// Kept around so the entity sections (People / Places / Themes) can be
/// composed back into Today without re-deriving them.
struct BrowseView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                placeholderRow(title: "People", count: store.people.count)
                placeholderRow(title: "Places", count: placeCount)
                placeholderRow(title: "Themes", count: themeCount)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
    }

    private var placeCount: Int {
        Set(store.moments.flatMap { $0.tags }.filter { $0.first?.isUppercase == true }).count
    }

    private var themeCount: Int {
        Set(store.moments.flatMap { $0.tags }).count
    }

    private func placeholderRow(title: String, count: Int) -> some View {
        Card {
            HStack {
                Text(title).font(Theme.cardTitle())
                Spacer()
                Text("\(count)")
                    .font(Theme.body())
                    .foregroundStyle(Theme.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
