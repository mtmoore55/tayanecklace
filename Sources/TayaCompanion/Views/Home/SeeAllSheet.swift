import SwiftUI

/// The destinations each "See all" link on Home routes to. Mirrors the
/// Home sections that expose a see-all affordance.
enum SeeAllRoute: String, Identifiable, Hashable {
    case people, places, themes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .people:  return "People"
        case .places:  return "Places"
        case .themes:  return "Themes"
        }
    }
}

/// Bottom sheet that opens when a Home eyebrow's "See all" is tapped.
/// Renders as a list view — one connected glass card per route, rows
/// each tappable into the corresponding detail sheet. Distinct from
/// the Home preview, which uses chips/avatars; the full list wants
/// more breathing room and a secondary line per item.
struct SeeAllSheet: View {
    let route: SeeAllRoute

    @Environment(DataStore.self) private var store
    @State private var sort: EntitySort = .recent
    /// The sheet self-presents its detail surfaces on top so the list
    /// stays mounted underneath — tapping a row stacks the detail
    /// rather than dismissing this sheet and re-presenting elsewhere.
    @State private var presentedDetail: HomeDetailRoute?

    /// Ordering options for the People / Places / Themes lists.
    /// Newest activity first is the default — matches how Home surfaces
    /// these (recently-touched entities take precedence).
    enum EntitySort: String, CaseIterable, Identifiable {
        case recent        = "Recent"
        case alphabetical  = "Alphabetical"
        case mostMentioned = "Most mentioned"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                titleRow
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $presentedDetail) { route in
            switch route {
            case .person(let id):
                PersonDetailSheet(personID: id).environment(store)
            case .place(let name):
                PlaceDetailSheet(place: name).environment(store)
            case .theme(let label):
                ThemeDetailSheet(theme: label).environment(store)
            }
        }
    }

    // MARK: - Header

    private var actionRow: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            ellipsisMenuButton
        }
    }

    private var ellipsisMenuButton: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(EntitySort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("More actions")
    }

    private var titleRow: some View {
        Text(route.title)
            .font(Theme.greeting())
            .foregroundStyle(Theme.primaryText)
            .lineSpacing(-10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .people:  peopleList
        case .places:  placesList
        case .themes:  themesList
        }
    }

    // MARK: - People

    @ViewBuilder
    private var peopleList: some View {
        let people = sortedPeople()
        if people.isEmpty {
            emptyState("No people yet.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        row(
                            leading: AnyView(
                                Text(String(person.name.prefix(1)))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 40, height: 40)
                                    .tayaInnerGlass(in: Circle())
                            ),
                            title: person.name,
                            subtitle: subtitle(forPerson: person)
                        ) {
                            presentedDetail = .person(person.id)
                        }
                        .padding(.horizontal, 12)
                        if index < people.count - 1 { divider }
                    }
                }
            }
        }
    }

    private func subtitle(forPerson person: Person) -> String? {
        let n = person.sourceMomentIDs.count
        guard n > 0 else { return person.facts.first }
        return n == 1 ? "1 mention" : "\(n) mentions"
    }

    // MARK: - Places

    @ViewBuilder
    private var placesList: some View {
        let places = sortedPlaces()
        if places.isEmpty {
            emptyState("No places yet.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(places.enumerated()), id: \.element) { index, place in
                        row(
                            leading: AnyView(glyphCircle(systemImage: "location.fill")),
                            title: place,
                            subtitle: subtitle(forPlace: place)
                        ) {
                            presentedDetail = .place(place)
                        }
                        .padding(.horizontal, 12)
                        if index < places.count - 1 { divider }
                    }
                }
            }
        }
    }

    private func subtitle(forPlace place: String) -> String? {
        let n = store.moments(at: place).count
        guard n > 0 else { return nil }
        return n == 1 ? "1 moment" : "\(n) moments"
    }

    // MARK: - Themes

    @ViewBuilder
    private var themesList: some View {
        let themes = sortedThemes()
        if themes.isEmpty {
            emptyState("No themes yet.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(themes.enumerated()), id: \.element) { index, theme in
                        row(
                            leading: AnyView(glyphCircle(systemImage: "number")),
                            title: theme,
                            subtitle: subtitle(forTheme: theme)
                        ) {
                            presentedDetail = .theme(theme)
                        }
                        .padding(.horizontal, 12)
                        if index < themes.count - 1 { divider }
                    }
                }
            }
        }
    }

    private func subtitle(forTheme theme: String) -> String? {
        let n = store.moments(taggedWith: theme).count
        guard n > 0 else { return nil }
        return n == 1 ? "1 moment" : "\(n) moments"
    }

    // MARK: - Sorting

    private func sortedPeople() -> [Person] {
        switch sort {
        case .recent:
            return store.people.sorted { $0.updatedAt > $1.updatedAt }
        case .alphabetical:
            return store.people.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostMentioned:
            return store.people.sorted { $0.sourceMomentIDs.count > $1.sourceMomentIDs.count }
        }
    }

    private func sortedPlaces() -> [String] {
        switch sort {
        case .recent:
            // Latest moment per place wins; absent places sink.
            return store.places.sorted { lhs, rhs in
                let l = store.moments(at: lhs).first?.createdAt ?? .distantPast
                let r = store.moments(at: rhs).first?.createdAt ?? .distantPast
                return l > r
            }
        case .alphabetical:
            return store.places.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .mostMentioned:
            return store.places.sorted { store.moments(at: $0).count > store.moments(at: $1).count }
        }
    }

    private func sortedThemes() -> [String] {
        switch sort {
        case .recent:
            return store.themes.sorted { lhs, rhs in
                let l = store.moments(taggedWith: lhs).first?.createdAt ?? .distantPast
                let r = store.moments(taggedWith: rhs).first?.createdAt ?? .distantPast
                return l > r
            }
        case .alphabetical:
            return store.themes.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .mostMentioned:
            return store.themes.sorted { store.moments(taggedWith: $0).count > store.moments(taggedWith: $1).count }
        }
    }

    // MARK: - Shared

    private var divider: some View {
        Divider()
            .padding(.horizontal, 12)
            .overlay(Theme.glassStroke.opacity(0.5))
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(Theme.bodyM())
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 72)
    }

    private func row(
        leading: AnyView,
        title: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.bodyL())
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func glyphCircle(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.accent)
            .frame(width: 40, height: 40)
            .tayaInnerGlass(in: Circle())
    }
}
