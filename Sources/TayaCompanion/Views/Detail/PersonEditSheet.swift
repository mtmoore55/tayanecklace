import SwiftUI

/// Edit an existing Person — rename, edit/add/remove the facts the app
/// remembers about them, or delete the entity. Opened from the
/// `PersonDetailSheet` ellipsis menu. Auto-merge from new Moments is
/// still the primary path; this is the manual override.
struct PersonEditSheet: View {
    let personID: Person.ID

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var facts: [EditableFact] = []
    @State private var didLoad: Bool = false
    @FocusState private var focusedFact: UUID?

    /// Wraps each fact with a stable id so adding/removing rows doesn't
    /// shuffle focus or cursor position. The ID is sheet-local and not
    /// persisted — only `text` flows back into the store on Save.
    private struct EditableFact: Identifiable {
        let id = UUID()
        var text: String
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nameCard
                    factsCard
                    deleteButton
                }
                .padding(20)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Edit person")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updatePerson(
                            id: personID,
                            name: name,
                            facts: facts.map(\.text)
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad, let person = store.person(personID) else { return }
        name = person.name
        facts = person.facts.map { EditableFact(text: $0) }
        didLoad = true
    }

    // MARK: - Cards

    private var nameCard: some View {
        Card {
            TextField("Name", text: $name)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .tint(Theme.primaryText)
        }
    }

    private var factsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Remember")
                    .font(Theme.micro())
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.tertiaryText)

                if facts.isEmpty {
                    Text("No facts yet.")
                        .font(Theme.bodyM())
                        .italic()
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(facts) { fact in
                            factRow(fact)
                            if fact.id != facts.last?.id {
                                Divider()
                                    .overlay(Theme.glassStroke.opacity(0.5))
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }

                addFactButton
                    .padding(.top, facts.isEmpty ? 0 : 4)
            }
        }
    }

    private func factRow(_ fact: EditableFact) -> some View {
        let binding = Binding<String>(
            get: { facts.first(where: { $0.id == fact.id })?.text ?? "" },
            set: { newValue in
                if let idx = facts.firstIndex(where: { $0.id == fact.id }) {
                    facts[idx].text = newValue
                }
            }
        )
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5, weight: .bold))
                .foregroundStyle(Theme.homeIcon)
                .padding(.top, 9)
            TextField("Fact", text: binding, axis: .vertical)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .tint(Theme.primaryText)
                .focused($focusedFact, equals: fact.id)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(.snappy) {
                    facts.removeAll { $0.id == fact.id }
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove fact")
        }
    }

    private var addFactButton: some View {
        Button {
            let new = EditableFact(text: "")
            withAnimation(.snappy) {
                facts.append(new)
            }
            // Defer focus until after the row mounts.
            DispatchQueue.main.async {
                focusedFact = new.id
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add fact")
            }
            .font(Theme.bodyL())
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let person = store.person(personID) {
                store.deletePerson(person)
            }
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash")
                Text("Delete person")
            }
            .font(Theme.bodyL())
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .tayaGlassCard(in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

#Preview {
    let store = DataStore.seeded(now: Date())
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            if let person = store.people.first {
                PersonEditSheet(personID: person.id).environment(store)
            }
        }
}
