import SwiftUI

/// The destinations each "See all" link on Home routes to. Mirrors the
/// Home sections that expose a see-all affordance.
enum SeeAllRoute: String, Identifiable, Hashable {
    case journal, people, places, themes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journal: return "Journal"
        case .people:  return "People"
        case .places:  return "Places"
        case .themes:  return "Themes"
        }
    }
}

/// Bottom sheet that opens when a Home eyebrow's "See all" is tapped.
/// One view, route-driven content — reuses the same card components that
/// the Home sections render, just with no preview limit applied. Taps
/// inside fall back through `onOpenMoment` / `onOpenDetail` so the parent
/// can dismiss this sheet and present the corresponding detail.
struct SeeAllSheet: View {
    let route: SeeAllRoute
    let onOpenMoment: (UUID) -> Void
    let onOpenDetail: (HomeDetailRoute) -> Void

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.backgroundGradient)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(route.title)
                .font(Theme.displayXL())
                .foregroundStyle(Theme.primaryText)
            Spacer()
            Button("Done") { dismiss() }
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .journal: journalList
        case .people:  peopleList
        case .places:  placesList
        case .themes:  themesList
        }
    }

    // MARK: - Journal (every kind: .journal moment, newest first)

    private var journalList: some View {
        let journals = store.moments
            .filter { $0.kind == .journal }
            .sorted { $0.createdAt > $1.createdAt }
        return VStack(spacing: 12) {
            ForEach(journals) { moment in
                Button {
                    onOpenMoment(moment.id)
                } label: {
                    JournalCard(moment: moment)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - People

    private var peopleList: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 16
        ) {
            ForEach(store.people) { person in
                PersonAvatar(person: person, onTap: {
                    onOpenDetail(.person(person.id))
                })
            }
        }
    }

    // MARK: - Places

    private var placesList: some View {
        ChipFlow(items: store.places, systemImage: "location.fill", onTap: { place in
            onOpenDetail(.place(place))
        })
    }

    // MARK: - Themes

    private var themesList: some View {
        ChipFlow(items: store.themes, onTap: { theme in
            onOpenDetail(.theme(theme))
        })
    }
}
