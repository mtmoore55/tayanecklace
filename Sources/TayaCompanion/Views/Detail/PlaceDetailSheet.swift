import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Place detail. Sits inside `PagedDetailChrome` so swiping flips
/// between every known place. Single-view body — pill is
/// ellipsis-only. Body shows open tasks tied to this place plus a card
/// with the Moments captured here.
struct PlaceDetailSheet: View {
    let place: String
    @Environment(DataStore.self) private var store
    @State private var currentID: String
    @State private var presentedMoment: MomentRoute?
    @State private var presentedTask: TaskRoute?
    @State private var askTayaQuery: String?

    init(place: String) {
        self.place = place
        self._currentID = State(initialValue: place)
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
        .sheet(item: $presentedTask) { route in
            TaskDetailSheet(taskID: route.id).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private var siblingIDs: [String] {
        let ids = store.places
        return ids.contains(place) ? ids : ([place] + ids)
    }

    // MARK: - Pill

    private func pill(for placeName: String) -> some View {
        let moments = store.moments(at: placeName)
        return DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            Button {
                askTayaQuery = "What have I captured about \(placeName)?"
            } label: {
                Label("Ask Taya", systemImage: "sparkles")
            }
            Button {
                copy(placeName)
            } label: {
                Label("Copy name", systemImage: "doc.on.doc")
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

    private func page(for placeName: String) -> some View {
        let moments = store.moments(at: placeName)
        let tasks = openTasks(linkedTo: moments)
        return PagedDetailPage(
            title: placeName,
            subtitle: subtitle(momentCount: moments.count)
        ) {
            body(placeName: placeName, moments: moments, tasks: tasks)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func body(placeName: String, moments: [Moment], tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            if !tasks.isEmpty {
                tasksSection(tasks: tasks)
            }
            momentsSection(placeName: placeName, moments: moments)
        }
    }

    private func tasksSection(tasks: [TaskItem]) -> some View {
        DetailSection(title: "Open tasks") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tasks) { task in
                    Button {
                        presentedTask = TaskRoute(id: task.id)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: "circle")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(Theme.tertiaryText)
                            Text(task.text)
                                .font(Theme.bodyL())
                                .foregroundStyle(Theme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func momentsSection(placeName: String, moments: [Moment]) -> some View {
        DetailSection(title: "Moments here") {
            if moments.isEmpty {
                DetailEmptyText(text: "No captured moments mention \(placeName) yet.")
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

    private func openTasks(linkedTo moments: [Moment]) -> [TaskItem] {
        let ids = Set(moments.map(\.id))
        return store.tasks
            .filter { $0.status == .open && $0.sourceMomentIDs.contains(where: ids.contains) }
    }

    private func subtitle(momentCount: Int) -> String {
        switch momentCount {
        case 0: return "No moments yet"
        case 1: return "1 moment here"
        default: return "\(momentCount) moments here"
        }
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
    PlaceDetailSheet(place: "Oakland")
        .environment(DataStore.seeded(now: Date()))
}
