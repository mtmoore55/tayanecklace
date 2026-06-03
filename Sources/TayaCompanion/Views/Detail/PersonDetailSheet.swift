import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Person detail. Sits inside `DetailChrome`. Single-view (Person is
/// not a transcript), so the action pill is ellipsis-only. The body
/// shows facts plainly on the surface, then a card with the Moments
/// that mention this person — provenance per the data model.
struct PersonDetailSheet: View {
    let personID: Person.ID
    @Environment(DataStore.self) private var store
    @State private var presentedMoment: MomentRoute?
    @State private var askTayaQuery: String?
    @State private var showEdit: Bool = false

    var body: some View {
        Group {
            if let person = store.person(personID) {
                detail(for: person)
            } else {
                notFound
            }
        }
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route).environment(store)
        }
        .sheet(isPresented: $showEdit) {
            PersonEditSheet(personID: personID).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    // MARK: - Chrome

    private func detail(for person: Person) -> some View {
        let mentions = store.moments(mentioning: person.id)
        return DetailChrome(
            title: person.name,
            subtitle: subtitle(facts: person.facts.count, mentions: mentions.count),
            pill: pill(for: person),
            leading: { avatar(for: person) }
        ) {
            body(for: person, mentions: mentions)
        }
    }

    private func avatar(for person: Person) -> some View {
        Text(String(person.name.prefix(1)))
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .frame(width: 52, height: 52)
            .tayaGlassCard(in: Circle())
    }

    private func pill(for person: Person) -> some View {
        DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            Button {
                askTayaQuery = "What's important about \(person.name)?"
            } label: {
                Label("Ask Taya", systemImage: "sparkles")
            }
            Button {
                showEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            ShareLink(item: shareMarkdown(for: person)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                copy(person.name)
            } label: {
                Label("Copy name", systemImage: "doc.on.doc")
            }
        }
    }

    private var notFound: some View {
        DetailChrome(
            title: "Person not found",
            subtitle: nil,
            pill: emptyPill
        ) {
            DetailEmptyText(text: "This person is no longer available.")
        }
    }

    private var emptyPill: some View {
        DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            EmptyView()
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func body(for person: Person, mentions: [Moment]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            factsSection(for: person)
            mentionsSection(mentions: mentions)
        }
    }

    private func factsSection(for person: Person) -> some View {
        DetailSection(title: "Remember") {
            if person.facts.isEmpty {
                DetailEmptyText(text: "No facts captured yet.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(person.facts.enumerated()), id: \.offset) { _, fact in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5, weight: .bold))
                                .foregroundStyle(Theme.homeIcon)
                                .padding(.top, 6)
                            Text(fact)
                                .font(Theme.bodyL())
                                .foregroundStyle(Theme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mentionsSection(mentions: [Moment]) -> some View {
        DetailSection(title: "Mentioned in") {
            if mentions.isEmpty {
                DetailEmptyText(text: "Not mentioned in any captured moments yet.")
            } else {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(mentions.enumerated()), id: \.element.id) { i, moment in
                            Button {
                                presentedMoment = MomentRoute(ids: mentions.map(\.id), startID: moment.id)
                            } label: {
                                MomentRow(moment: moment)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            if i < mentions.count - 1 {
                                Divider().padding(.horizontal, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func subtitle(facts: Int, mentions: Int) -> String {
        let f = "\(facts) fact\(facts == 1 ? "" : "s")"
        let m = "\(mentions) mention\(mentions == 1 ? "" : "s")"
        return "\(f) · \(m)"
    }

    private func shareMarkdown(for person: Person) -> String {
        var lines: [String] = ["# \(person.name)"]
        if !person.facts.isEmpty {
            lines.append("")
            for fact in person.facts { lines.append("- \(fact)") }
        }
        return lines.joined(separator: "\n")
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private struct AskTayaSeed: Identifiable {
    let id = UUID()
    let query: String
}

#Preview {
    let store = DataStore.seeded(now: Date())
    if let person = store.people.first {
        PersonDetailSheet(personID: person.id)
            .environment(store)
    } else {
        Text("No seed people")
    }
}
