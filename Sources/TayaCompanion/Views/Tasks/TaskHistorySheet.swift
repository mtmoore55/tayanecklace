import SwiftUI

/// Archive — completed tasks, grouped by the day they were completed
/// (newest day first), one connected glass card per day. Stacked
/// sheet from the clock icon in `TasksView`.
struct TaskHistorySheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var editingTask: TaskItem?
    @State private var presentedMoment: MomentRoute?
    @State private var showRecentlyDeleted: Bool = false
    @State private var confirmClearCompleted: Bool = false

    var body: some View {
        let groups = store.completedTasksGroupedByDay()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                titleRow
                content(groups: groups)
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $editingTask) { task in
            TaskEditSheet(task: task, onViewSource: { id in
                editingTask = nil
                presentedMoment = MomentRoute(ids: [id], startID: id)
            })
            .environment(store)
        }
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route)
                .environment(store)
        }
        .sheet(isPresented: $showRecentlyDeleted) {
            RecentlyDeletedTasksSheet().environment(store)
        }
        .onAppear { store.purgeExpiredDeletedTasks() }
        .confirmationDialog(
            "Clear completed tasks?",
            isPresented: $confirmClearCompleted,
            titleVisibility: .visible
        ) {
            Button("Clear completed", role: .destructive) {
                withAnimation(.snappy) { store.clearCompletedTasks() }
                Haptics.commit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every task from history. It can't be undone.")
        }
    }

    // MARK: - Header

    private var actionRow: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            ellipsisMenuButton
        }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Archive")
                .font(Theme.greeting())
                .foregroundStyle(Theme.primaryText)
                .lineSpacing(-10)
            Text("Completed tasks land here.")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ellipsisMenuButton: some View {
        Menu {
            Button {
                showRecentlyDeleted = true
            } label: {
                Label("Recently deleted", systemImage: "trash.slash")
            }
            Divider()
            Button(role: .destructive) {
                confirmClearCompleted = true
            } label: {
                Label("Clear completed", systemImage: "trash")
            }
            .disabled(store.completedTasks().isEmpty)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("More actions")
    }

    @ViewBuilder
    private func content(groups: [TaskDayGroup]) -> some View {
        if groups.isEmpty {
            Text("Nothing here")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 72)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups) { group in
                    daySection(label: dayLabel(group.day), tasks: group.tasks)
                }
            }
        }
    }

    private func daySection(label: String, tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label)
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(
                            task: task,
                            onToggle: {
                                Haptics.toggle()
                                withAnimation(.snappy) { store.toggle(task) }
                            },
                            onTapBody: {
                                Haptics.tap()
                                editingTask = task
                            }
                        )
                        .padding(.horizontal, 12)
                        .contextMenu { rowMenu(task) }
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

    @ViewBuilder
    private func rowMenu(_ task: TaskItem) -> some View {
        Button {
            Haptics.toggle()
            withAnimation(.snappy) { store.toggle(task) }
        } label: {
            Label("Mark as not done", systemImage: "arrow.uturn.left")
        }
        Button {
            Haptics.tap()
            editingTask = task
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive) {
            Haptics.commit()
            withAnimation(.snappy) { store.deleteTask(task) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.micro())
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondaryText)
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

#Preview {
    TaskHistorySheet()
        .environment(DataStore.seeded(now: Date()))
}
