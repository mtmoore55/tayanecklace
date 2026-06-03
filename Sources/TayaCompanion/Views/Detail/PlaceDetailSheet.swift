import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Place detail. Sits inside `DetailChrome`. Single-view, so the
/// action pill is ellipsis-only. The body shows open tasks tied to
/// this place plainly on the surface, then a card with the Moments
/// captured here.
struct PlaceDetailSheet: View {
    let place: String
    @Environment(DataStore.self) private var store
    @State private var presentedMoment: MomentRoute?
    @State private var presentedTask: TaskRoute?
    @State private var askTayaQuery: String?

    var body: some View {
        detail
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

    // MARK: - Chrome

    private var detail: some View {
        let moments = store.moments(at: place)
        let tasks = openTasks(linkedTo: moments)
        return DetailChrome(
            title: place,
            subtitle: subtitle(momentCount: moments.count),
            pill: pill
        ) {
            body(moments: moments, tasks: tasks)
        }
    }

    private var pill: some View {
        DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            Button {
                askTayaQuery = "What have I captured about \(place)?"
            } label: {
                Label("Ask Taya", systemImage: "sparkles")
            }
            Button {
                copy(place)
            } label: {
                Label("Copy name", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func body(moments: [Moment], tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            if !tasks.isEmpty {
                tasksSection(tasks: tasks)
            }
            momentsSection(moments: moments)
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
    private func momentsSection(moments: [Moment]) -> some View {
        DetailSection(title: "Moments here") {
            if moments.isEmpty {
                DetailEmptyText(text: "No captured moments mention \(place) yet.")
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
