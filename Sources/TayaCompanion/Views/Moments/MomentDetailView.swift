import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Identifies which moment a sheet should open on, plus the ordered
/// sibling list it sits in. The sheet pages horizontally between the
/// `ids`; `startID` is which one to centre when the sheet first
/// appears. Sheet identity uses `startID`, so swiping inside doesn't
/// dismiss/re-present.
struct MomentRoute: Identifiable, Hashable {
    let ids: [Moment.ID]
    let startID: Moment.ID
    var id: Moment.ID { startID }

    init(ids: [Moment.ID], startID: Moment.ID) {
        self.ids = ids.isEmpty ? [startID] : ids
        self.startID = startID
    }
}

/// Moment detail. Sits inside `PagedDetailChrome`: an ellipsis-only
/// glass action pill pinned in the top-right, with title + body paging
/// horizontally between sibling moments. Each page surfaces
/// AI-extracted facets (Tasks, People, Places, Tags) followed by the
/// verbatim transcript at the bottom.
struct MomentDetailView: View {
    let route: MomentRoute
    @Environment(DataStore.self) private var store

    @State private var currentID: Moment.ID
    @State private var askTayaQuery: String?
    @State private var presentedEntity: HomeDetailRoute?
    @State private var presentedTask: TaskRoute?
    @State private var copyToast: ToastMessage?

    init(route: MomentRoute) {
        self.route = route
        let initial = route.ids.contains(route.startID) ? route.startID : (route.ids.first ?? route.startID)
        self._currentID = State(initialValue: initial)
    }

    var body: some View {
        PagedDetailChrome(
            items: route.ids,
            currentID: $currentID,
            pill: { id in pill(for: id) },
            page: { id in page(for: id) }
        )
        .tayaToast($copyToast)
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

    // MARK: - Pill

    @ViewBuilder
    private func pill(for id: Moment.ID) -> some View {
        if let moment = store.moment(id) {
            DetailActionPill(
                modes: [],
                selectedModeID: .constant("")
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
    private func page(for id: Moment.ID) -> some View {
        if let moment = store.moment(id) {
            PagedDetailPage(
                title: moment.title,
                subtitle: subtitle(for: moment)
            ) {
                body(for: moment)
            }
        } else {
            PagedDetailPage(
                title: "Moment not found",
                subtitle: nil
            ) {
                DetailEmptyText(text: "This moment is no longer available.")
            }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func body(for moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            summarySection(for: moment)
            tasksSection(for: moment)
            peopleSection(for: moment)
            placesSection(for: moment)
            tagsSection(for: moment)
            transcriptSection(for: moment)
        }
    }

    private func summarySection(for moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            copyableSectionHeader(title: "Summary", text: moment.polishedSummary)
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

    /// Section header with a trailing copy-to-clipboard button. Disabled
    /// when there's nothing to copy so the icon greys out instead of
    /// firing an empty toast.
    private func copyableSectionHeader(title: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(Theme.titleS())
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 8)
            Button {
                copy(text)
                copyToast = ToastMessage(text: "Copied")
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(text.isEmpty ? Theme.tertiaryText : Theme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.accentSoft))
                    .contentShape(Circle())
                    .opacity(text.isEmpty ? 0.55 : 1)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
            .accessibilityLabel("Copy \(title.lowercased())")
        }
    }

    @ViewBuilder
    private func tasksSection(for moment: Moment) -> some View {
        let tasks = store.tasks(from: moment.id)
        if !tasks.isEmpty {
            DetailSection(title: "Tasks") {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            TaskRow(
                                task: task,
                                onToggle: { store.toggle(task) },
                                onTapBody: { presentedTask = TaskRoute(id: task.id) }
                            )
                            .padding(.horizontal, 12)
                            if index < tasks.count - 1 {
                                Divider()
                                    .padding(.horizontal, 12)
                                    .overlay(Theme.glassStroke.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
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

    // MARK: - Transcript

    private func transcriptSection(for moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            copyableSectionHeader(title: "Transcript", text: moment.rawTranscript)
            if moment.rawTranscript.isEmpty {
                DetailEmptyText(text: "No transcript available.")
            } else {
                Text(moment.rawTranscript)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        Haptics.success()
    }
}

private struct MomentAskSeed: Identifiable {
    let query: String
    var id: String { query }
}
