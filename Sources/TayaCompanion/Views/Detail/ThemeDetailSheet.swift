import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Theme (tag) detail. Sits inside `PagedDetailChrome` so the user can
/// swipe between every theme. Single-view body — pill is
/// ellipsis-only. The body lists People who recur in this theme as
/// inline links, then a card with the Moments tagged by it.
struct ThemeDetailSheet: View {
    let theme: String
    @Environment(DataStore.self) private var store
    @State private var currentID: String
    @State private var presentedMoment: MomentRoute?
    @State private var presentedPerson: Person.ID?
    @State private var askTayaQuery: String?

    init(theme: String) {
        self.theme = theme
        self._currentID = State(initialValue: theme)
    }

    var body: some View {
        PagedDetailChrome(
            items: siblingIDs,
            currentID: $currentID,
            pill: { id in pill(for: id) },
            page: { id in page(for: id) }
        )
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route).environment(store)
        }
        .sheet(item: Binding(
            get: { presentedPerson.map { PersonRoute(id: $0) } },
            set: { presentedPerson = $0?.id }
        )) { route in
            PersonDetailSheet(personID: route.id).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private var siblingIDs: [String] {
        let ids = store.themes
        return ids.contains(theme) ? ids : ([theme] + ids)
    }

    // MARK: - Pill

    private func pill(for themeName: String) -> some View {
        let moments = store.moments(taggedWith: themeName)
        return DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            Button {
                askTayaQuery = "What have I captured about \(themeName)?"
            } label: {
                Label("Ask Taya", systemImage: "sparkles")
            }
            Button {
                copy(themeName)
            } label: {
                Label("Copy tag", systemImage: "doc.on.doc")
            }
            Button {
                copy(MomentExport.markdown(for: moments, store: store))
            } label: {
                Label("Copy all moments", systemImage: "doc.on.doc.fill")
            }
            .disabled(moments.isEmpty)
        }
    }

    // MARK: - Page

    private func page(for themeName: String) -> some View {
        let moments = store.moments(taggedWith: themeName)
        let people = store.people(forTheme: themeName)
        return PagedDetailPage(
            title: themeName,
            subtitle: subtitle(momentCount: moments.count)
        ) {
            body(themeName: themeName, moments: moments, people: people)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func body(themeName: String, moments: [Moment], people: [Person]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            if !people.isEmpty {
                peopleSection(people: people)
            }
            momentsSection(themeName: themeName, moments: moments)
        }
    }

    private func peopleSection(people: [Person]) -> some View {
        DetailSection(title: "People") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(people) { person in
                    DetailEntityLink(label: person.name) {
                        presentedPerson = person.id
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func momentsSection(themeName: String, moments: [Moment]) -> some View {
        DetailSection(title: "Moments") {
            if moments.isEmpty {
                DetailEmptyText(text: "No moments tagged #\(themeName) yet.")
            } else {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(moments.enumerated()), id: \.element.id) { i, moment in
                            Button {
                                presentedMoment = MomentRoute(ids: moments.map(\.id), startID: moment.id)
                            } label: {
                                MomentRow(moment: moment)
                                .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            if i < moments.count - 1 {
                                Divider().padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func subtitle(momentCount: Int) -> String {
        switch momentCount {
        case 0: return "No moments tagged"
        case 1: return "1 moment tagged"
        default: return "\(momentCount) moments tagged"
        }
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        Haptics.success()
    }
}

private struct PersonRoute: Identifiable, Hashable {
    let id: Person.ID
}

private struct AskTayaSeed: Identifiable {
    let id = UUID()
    let query: String
}

#Preview {
    ThemeDetailSheet(theme: "recommendation")
        .environment(DataStore.seeded(now: Date()))
}
