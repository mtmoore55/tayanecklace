import SwiftUI
import TayaIntelligence

struct PersonDetailSheet: View {
    let personID: Person.ID
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var presentedMoment: MomentRoute?
    @State private var askTayaQuery: String?

    var body: some View {
        Group {
            if let person = store.person(personID) {
                content(for: person)
            } else {
                ContentUnavailableView("Person not found", systemImage: "person")
            }
        }
        .background(Theme.background)
        .presentationDragIndicator(.visible)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            NewChatSheet(initialDraft: seed.query, autoSubmit: true)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(for person: Person) -> some View {
        let mentions = store.moments(mentioning: person.id)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(for: person, mentionCount: mentions.count)
                rememberCard(for: person)
                mentionedInCard(mentions: mentions)
                askTayaCTA(for: person)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(for person: Person, mentionCount: Int) -> some View {
        VStack(spacing: 14) {
            Text(String(person.name.prefix(1)))
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(TayaColors.oxfordBlue)
                .frame(width: 96, height: 96)
                .background(TayaColors.skyBlue.opacity(0.32), in: Circle())

            VStack(spacing: 4) {
                Text(person.name)
                    .font(Theme.titleL())
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle(facts: person.facts.count, mentions: mentionCount))
                    .font(Theme.bodyS())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func subtitle(facts: Int, mentions: Int) -> String {
        let f = "\(facts) fact\(facts == 1 ? "" : "s")"
        let m = "\(mentions) mention\(mentions == 1 ? "" : "s")"
        return "\(f) · \(m)"
    }

    @ViewBuilder
    private func rememberCard(for person: Person) -> some View {
        if !person.facts.isEmpty {
            sectionFrame(eyebrow: "Remember") {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(person.facts.enumerated()), id: \.offset) { i, fact in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 7)
                                Text(fact)
                                    .font(Theme.bodyL())
                                    .foregroundStyle(Theme.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            if i < person.facts.count - 1 {
                                Divider().padding(.leading, 28)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mentionedInCard(mentions: [Moment]) -> some View {
        if !mentions.isEmpty {
            sectionFrame(eyebrow: "Mentioned in") {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(mentions.enumerated()), id: \.element.id) { i, moment in
                            Button {
                                presentedMoment = MomentRoute(id: moment.id)
                            } label: {
                                MomentRow(moment: moment)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            if i < mentions.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private func askTayaCTA(for person: Person) -> some View {
        Button {
            askTayaQuery = "What's important about \(person.name)?"
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("Ask Taya about \(person.name)")
                    .font(Theme.bodyL().weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule(style: .continuous).fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func sectionFrame<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }
}

/// Tiny wrapper so `.sheet(item:)` can present NewChatSheet with a query.
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
