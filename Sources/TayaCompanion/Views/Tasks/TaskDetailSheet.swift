import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Identifiable wrapper so a task can drive `.sheet(item:)` presentation.
struct TaskRoute: Identifiable, Hashable {
    let id: TaskItem.ID
}

/// Task detail. Sits inside `PagedDetailChrome` so the user can swipe
/// horizontally through every task in the store — same shape as the
/// Moment detail. Single-view body (no AI/Raw split), so the action
/// pill is ellipsis-only.
struct TaskDetailSheet: View {
    let taskID: TaskItem.ID

    @Environment(DataStore.self) private var store
    @State private var currentID: TaskItem.ID
    @State private var askTayaQuery: String?
    @State private var presentedMoment: MomentRoute?

    init(taskID: TaskItem.ID) {
        self.taskID = taskID
        self._currentID = State(initialValue: taskID)
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
            get: { askTayaQuery.map { TaskAskSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    /// Ordered IDs the swipe pager walks between. Pulls from
    /// `store.tasks` so the carousel always reflects the live list;
    /// guards the initial ID in case the source task has been deleted
    /// out from under us.
    private var siblingIDs: [TaskItem.ID] {
        let ids = store.tasks.map(\.id)
        return ids.contains(taskID) ? ids : ([taskID] + ids)
    }

    // MARK: - Pill

    @ViewBuilder
    private func pill(for id: TaskItem.ID) -> some View {
        if let task = store.task(id) {
            DetailActionPill(
                modes: [],
                selectedModeID: .constant("")
            ) {
                Button {
                    Haptics.toggle()
                    withAnimation(.snappy) { store.toggle(task) }
                } label: {
                    Label(
                        task.status == .done ? "Mark not done" : "Mark complete",
                        systemImage: task.status == .done ? "circle" : "checkmark.circle"
                    )
                }
                Button {
                    askTayaQuery = "Tell me about this task: \"\(task.text)\""
                } label: {
                    Label("Ask Taya", systemImage: "sparkles")
                }
                ShareLink(item: shareMarkdown(for: task)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    copy(task.text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
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
    private func page(for id: TaskItem.ID) -> some View {
        if let task = store.task(id) {
            PagedDetailPage(
                title: task.text,
                subtitle: subtitle(for: task)
            ) {
                body(for: task)
            }
        } else {
            PagedDetailPage(
                title: "Task not found",
                subtitle: nil
            ) {
                DetailEmptyText(text: "This task is no longer available.")
            }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private func body(for task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            statusSection(for: task)
            if task.dueAt != nil {
                dueSection(for: task)
            }
            sourceSection(for: task)
        }
    }

    private func statusSection(for task: TaskItem) -> some View {
        let isDone = task.status == .done
        return DetailSection(title: "Status") {
            Button {
                Haptics.toggle()
                withAnimation(.snappy) { store.toggle(task) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(isDone ? Theme.homeIcon : Theme.tertiaryText)
                    Text(isDone ? "Completed" : "Open")
                        .font(Theme.bodyL())
                        .foregroundStyle(Theme.primaryText)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark as not done" : "Mark as complete")
        }
    }

    @ViewBuilder
    private func dueSection(for task: TaskItem) -> some View {
        if let due = task.dueAt {
            DetailSection(title: "Due") {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.tertiaryText)
                    Text(due.formatted(date: .long, time: .omitted))
                        .font(Theme.bodyL())
                        .foregroundStyle(Theme.primaryText)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func sourceSection(for task: TaskItem) -> some View {
        if let source = store.sourceMoment(of: task) {
            DetailSection(title: "From this moment") {
                Card(padding: 4) {
                    Button {
                        presentedMoment = MomentRoute(ids: [source.id], startID: source.id)
                    } label: {
                        MomentRow(moment: source)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func subtitle(for task: TaskItem) -> String? {
        switch task.status {
        case .done: return "Completed"
        case .open:
            guard let due = task.dueAt else { return nil }
            return "Due \(due.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func shareMarkdown(for task: TaskItem) -> String {
        var lines: [String] = ["- [\(task.status == .done ? "x" : " ")] \(task.text)"]
        if let due = task.dueAt {
            lines.append("  *Due \(due.formatted(date: .long, time: .omitted))*")
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

private struct TaskAskSeed: Identifiable {
    let query: String
    var id: String { query }
}

#Preview {
    let store = DataStore.seeded(now: Date())
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            if let task = store.tasks.first {
                TaskDetailSheet(taskID: task.id).environment(store)
            }
        }
}
