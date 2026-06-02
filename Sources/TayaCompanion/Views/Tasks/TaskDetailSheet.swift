import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Identifiable wrapper so a task can drive `.sheet(item:)` presentation.
struct TaskRoute: Identifiable, Hashable {
    let id: TaskItem.ID
}

/// Task detail. Sits inside `DetailChrome`. Single-view content (no
/// AI/Raw split — there's no transcript layer for a Task entity), so
/// the action pill is ellipsis-only. The body shows status, due date,
/// and the Moment that originated the task as a tappable card.
struct TaskDetailSheet: View {
    let taskID: TaskItem.ID

    @Environment(DataStore.self) private var store
    @State private var askTayaQuery: String?
    @State private var presentedMoment: MomentRoute?

    var body: some View {
        Group {
            if let task = store.task(taskID) {
                detail(for: task)
            } else {
                notFound
            }
        }
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { TaskAskSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    // MARK: - Chrome

    private func detail(for task: TaskItem) -> some View {
        DetailChrome(
            title: task.text,
            subtitle: subtitle(for: task),
            pill: pill(for: task)
        ) {
            body(for: task)
        }
    }

    private func pill(for task: TaskItem) -> some View {
        DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            Button {
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
    }

    private var notFound: some View {
        DetailChrome(
            title: "Task not found",
            subtitle: nil,
            pill: emptyPill
        ) {
            DetailEmptyText(text: "This task is no longer available.")
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
                        presentedMoment = MomentRoute(id: source.id)
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
