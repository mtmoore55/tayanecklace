import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Person detail. Sits inside `PagedDetailChrome` — same horizontal
/// swipe model as Moment / Task — so the user can flick between every
/// known person without dismissing the sheet. Single-view content
/// (Person is not a transcript), so the action pill is ellipsis-only.
struct PersonDetailSheet: View {
    let personID: Person.ID
    @Environment(DataStore.self) private var store
    @State private var currentID: Person.ID
    @State private var presentedMoment: MomentRoute?
    @State private var askTayaQuery: String?
    @State private var showEdit: Bool = false

    init(personID: Person.ID) {
        self.personID = personID
        self._currentID = State(initialValue: personID)
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
        .sheet(isPresented: $showEdit) {
            PersonEditSheet(personID: currentID).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private var siblingIDs: [Person.ID] {
        let ids = store.people.map(\.id)
        return ids.contains(personID) ? ids : ([personID] + ids)
    }

    // MARK: - Pill

    @ViewBuilder
    private func pill(for id: Person.ID) -> some View {
        if let person = store.person(id) {
            let mentions = store.moments(mentioning: person.id)
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
                Button {
                    copy(MomentExport.markdown(for: mentions, store: store))
                } label: {
                    Label("Copy all moments", systemImage: "doc.on.doc.fill")
                }
                .disabled(mentions.isEmpty)
            }
        } else {
            DetailActionPill(
                modes: [],
                selectedModeID: .constant("")
            ) {
                EmptyView()
            }
        }
    }

    // MARK: - Page

    @ViewBuilder
    private func page(for id: Person.ID) -> some View {
        if let person = store.person(id) {
            let mentions = store.moments(mentioning: person.id)
            PagedDetailPage(
                title: person.name,
                subtitle: subtitle(facts: person.facts.count, mentions: mentions.count),
                leading: { avatar(for: person) }
            ) {
                body(for: person, mentions: mentions)
            }
        } else {
            PagedDetailPage(
                title: "Person not found",
                subtitle: nil
            ) {
                DetailEmptyText(text: "This person is no longer available.")
            }
        }
    }

    private func avatar(for person: Person) -> some View {
        Text(String(person.name.prefix(1)))
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .frame(width: 52, height: 52)
            .tayaGlassCard(in: Circle())
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
        Haptics.success()
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
