import SwiftUI

/// Identifiable wrapper so a task can drive `.sheet(item:)` presentation.
struct TaskRoute: Identifiable, Hashable {
    let id: TaskItem.ID
}

/// Bottom sheet shown when a task row is tapped. The task text is the
/// title, completion is a single tap inside the sheet, and the source
/// moment (if any) is offered as a card that opens the full Moment
/// detail.
struct TaskDetailSheet: View {
    let taskID: TaskItem.ID
    /// Called when the user taps the source-moment card. The parent
    /// dismisses this sheet and presents the moment detail so the two
    /// sheets don't stack.
    var onOpenMoment: (UUID) -> Void = { _ in }

    @Environment(DataStore.self) private var store
    @State private var askTayaQuery: String?

    var body: some View {
        Group {
            if let task = store.task(taskID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleRow(for: task)
                        completeToggle(for: task)
                        if let due = task.dueAt {
                            dueDateRow(due)
                        }
                        if let source = store.sourceMoment(of: task) {
                            sourceCard(source)
                        }
                        actionsRow(for: task)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView("Task not found", systemImage: "checklist")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.backgroundGradient.ignoresSafeArea())
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: Binding(
            get: { askTayaQuery.map { TaskAskSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private func actionsRow(for task: TaskItem) -> some View {
        MomentActionsRow(
            onChat: { askTayaQuery = "Tell me about this task: \"\(task.text)\"" },
            copyText: task.text,
            shareItem: shareMarkdown(for: task)
        )
        .padding(.top, 8)
    }

    private func shareMarkdown(for task: TaskItem) -> String {
        var lines: [String] = ["- [\(task.status == .done ? "x" : " ")] \(task.text)"]
        if let due = task.dueAt {
            lines.append("  *Due \(due.formatted(date: .long, time: .omitted))*")
        }
        return lines.joined(separator: "\n")
    }

    private func titleRow(for task: TaskItem) -> some View {
        Text(task.text)
            .font(Theme.titleM())
            .foregroundStyle(Theme.primaryText)
            .strikethrough(task.status == .done, color: Theme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func completeToggle(for task: TaskItem) -> some View {
        let isDone = task.status == .done
        return Button {
            withAnimation(.snappy) { store.toggle(task) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(isDone ? Theme.homeIcon : Color.white.opacity(0.9))
                Text(isDone ? "Completed" : "Mark as complete")
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tayaGlassCard(in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDone ? "Mark as not done" : "Mark as complete")
    }

    private func dueDateRow(_ due: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.homeIcon)
            Text("Due \(due.formatted(date: .long, time: .omitted))")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tayaGlassCard(in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    private func sourceCard(_ moment: Moment) -> some View {
        Button {
            onOpenMoment(moment.id)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("From this moment")
                    .font(Theme.micro())
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.tertiaryText)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(moment.title)
                            .font(Theme.bodyL())
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.leading)
                        Text(moment.polishedSummary.isEmpty ? moment.rawTranscript : moment.polishedSummary)
                            .font(Theme.bodyS())
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tayaGlassCard(in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open source moment: \(moment.title)")
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
