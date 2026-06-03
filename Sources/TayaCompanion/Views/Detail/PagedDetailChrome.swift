import SwiftUI

/// Paging variant of `DetailChrome`. The action pill in the top-right
/// stays pinned; the title row and body page horizontally between
/// siblings (the next/previous moment, task, etc.). Callers pass the
/// ordered sibling IDs plus a binding to the currently-centered ID,
/// then build the pill and per-page content from that ID.
///
/// Each page is a `PagedDetailPage`, which mirrors `DetailChrome`'s
/// title/subtitle/leading/body layout. A transparent placeholder under
/// the pinned pill keeps the title's vertical rhythm identical to the
/// non-paged chrome.
struct PagedDetailChrome<ID: Hashable, Pill: View, Page: View>: View {
    let items: [ID]
    @Binding var currentID: ID
    @ViewBuilder let pill: (ID) -> Pill
    @ViewBuilder let page: (ID) -> Page

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentID) {
                ForEach(items, id: \.self) { id in
                    page(id)
                        .tag(id)
                }
            }
            #if !os(macOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif

            pill(currentID)
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
    }
}

/// One page inside a `PagedDetailChrome`. Same layout shape as
/// `DetailChrome` minus the pill — a transparent header band keeps the
/// pinned pill's footprint clear so the title starts at the same
/// vertical position as in the non-paged chrome.
struct PagedDetailPage<Leading: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String?,
        @ViewBuilder content: @escaping () -> Content
    ) where Leading == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.leading = EmptyView()
        self.content = content
    }

    init(
        title: String,
        subtitle: String?,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Placeholder under the pinned pill so the title sits at
                // the same vertical position as in `DetailChrome`.
                Color.clear.frame(height: 44)

                HStack(alignment: .top, spacing: 14) {
                    leading
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.bodyM())
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .padding(.top, 24)

                content()
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }
}
