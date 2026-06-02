import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Identifiable wrapper so a moment can drive `.sheet(item:)` presentation
/// across the app without forcing every caller to wrap UUIDs manually.
struct MomentRoute: Identifiable, Hashable {
    let id: Moment.ID
}

/// Moment detail. Sits inside `DetailChrome`: a glass action pill in
/// the top-right (AI / Raw view toggle + ellipsis), a large
/// left-aligned title, and a body that flips between an AI-extracted
/// view of the captured content and the verbatim transcript. Facets
/// are named per the data model (Tasks, People, Places, Tags), and
/// each cites back to the entity it created.
struct MomentDetailView: View {
    let momentID: Moment.ID
    @Environment(DataStore.self) private var store

    @State private var mode: String = Self.aiMode
    @State private var askTayaQuery: String?
    @State private var presentedEntity: HomeDetailRoute?
    @State private var presentedTask: TaskRoute?

    private static let aiMode = "ai"
    private static let rawMode = "raw"

    var body: some View {
        Group {
            if let moment = store.moment(momentID) {
                detail(for: moment)
            } else {
                notFound
            }
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { MomentAskSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
        .sheet(item: $presentedEntity) { route in
            switch route {
            case .person(let id):
                PersonDetailSheet(personID: id).environment(store)
            case .place(let name):
                PlaceDetailSheet(place: name).environment(store)
            case .theme(let label):
                ThemeDetailSheet(theme: label).environment(store)
            }
        }
        .sheet(item: $presentedTask) { route in
            TaskDetailSheet(taskID: route.id).environment(store)
        }
    }

    // MARK: - Chrome

    private func detail(for moment: Moment) -> some View {
        DetailChrome(
            title: moment.title,
            subtitle: subtitle(for: moment),
            pill: pill(for: moment)
        ) {
            if mode == Self.rawMode {
                rawBody(for: moment)
            } else {
                aiBody(for: moment)
            }
        }
    }

    private func pill(for moment: Moment) -> some View {
        DetailActionPill(
            modes: [
                .init(id: Self.aiMode,  systemImage: "sparkles",       label: "AI summary"),
                .init(id: Self.rawMode, systemImage: "text.alignleft", label: "Raw transcript"),
            ],
            selectedModeID: $mode
        ) {
            Button {
                askTayaQuery = "Tell me more about \"\(moment.title)\""
            } label: {
                Label("Ask Taya", systemImage: "sparkles")
            }
            ShareLink(item: MomentExport.markdown(for: moment, store: store)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button {
                copy(moment.rawTranscript)
            } label: {
                Label("Copy transcript", systemImage: "doc.on.doc")
            }
        }
    }

    private var notFound: some View {
        DetailChrome(
            title: "Moment not found",
            subtitle: nil,
            pill: emptyPill
        ) {
            DetailEmptyText(text: "This moment is no longer available.")
        }
    }

    /// Empty-pill stand-in for the not-found path. Same dimensions as
    /// a live pill so the chrome doesn't reflow.
    private var emptyPill: some View {
        DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            EmptyView()
        }
    }

    // MARK: - AI body

    @ViewBuilder
    private func aiBody(for moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            summarySection(for: moment)
            tasksSection(for: moment)
            peopleSection(for: moment)
            placesSection(for: moment)
            tagsSection(for: moment)
        }
    }

    private func summarySection(for moment: Moment) -> some View {
        DetailSection(title: "Summary") {
            if moment.polishedSummary.isEmpty {
                DetailEmptyText(text: "No summary generated yet.")
            } else {
                Text(moment.polishedSummary)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func tasksSection(for moment: Moment) -> some View {
        let tasks = store.tasks(from: moment.id)
        if !tasks.isEmpty {
            DetailSection(title: "Tasks") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            presentedTask = TaskRoute(id: task.id)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(task.status == .done ? Theme.homeIcon : Theme.tertiaryText)
                Text(task.text)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                    .strikethrough(task.status == .done, color: Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func peopleSection(for moment: Moment) -> some View {
        let people = store.people(in: moment.id)
        if !people.isEmpty {
            DetailSection(title: "People") {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(people) { person in
                        chip(label: person.name, systemImage: "person.fill") {
                            presentedEntity = .person(person.id)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func placesSection(for moment: Moment) -> some View {
        let placeNames = places(in: moment)
        if !placeNames.isEmpty {
            DetailSection(title: "Places") {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(placeNames, id: \.self) { name in
                        chip(label: name, systemImage: "location.fill") {
                            presentedEntity = .place(name)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tagsSection(for moment: Moment) -> some View {
        if !moment.tags.isEmpty {
            DetailSection(title: "Tags") {
                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(moment.tags, id: \.self) { tag in
                        chip(label: tag, systemImage: "number") {
                            presentedEntity = .theme(tag)
                        }
                    }
                }
            }
        }
    }

    /// Glass capsule with icon + label for an extracted entity. Tapping
    /// routes to that entity's detail. Same shape across People, Places,
    /// and Tags so the three sections share a visual rhythm.
    private func chip(label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .regular))
                Text(label)
                    .font(Theme.caption())
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(Theme.accentSoft))
            .foregroundStyle(Theme.primaryText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Raw body

    private func rawBody(for moment: Moment) -> some View {
        Text(moment.rawTranscript.isEmpty ? "No transcript available." : moment.rawTranscript)
            .font(Theme.bodyL())
            .italic(moment.rawTranscript.isEmpty)
            .foregroundStyle(moment.rawTranscript.isEmpty ? Theme.secondaryText : Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Helpers

    private func subtitle(for moment: Moment) -> String {
        let source = moment.source == .necklace ? "Necklace" : "Phone"
        let when = moment.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(source) · \(when)"
    }

    /// Places tied to this moment: its explicit `place` plus any known
    /// places mentioned in its text. Deduped, explicit first.
    private func places(in moment: Moment) -> [String] {
        var result: [String] = []
        if let p = moment.place { result.append(p) }
        for place in store.places where !result.contains(place) {
            let mentioned = moment.title.localizedCaseInsensitiveContains(place)
                || moment.polishedSummary.localizedCaseInsensitiveContains(place)
                || moment.rawTranscript.localizedCaseInsensitiveContains(place)
            if mentioned { result.append(place) }
        }
        return result
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

private struct MomentAskSeed: Identifiable {
    let query: String
    var id: String { query }
}
