import SwiftUI

/// Tasks timeline — the full list of open and completed tasks, grouped by
/// day. Presented as a sheet from Home's "Tasks — See all" affordance.
/// Tasks within the same day render as one connected glass card with
/// dividers between rows, matching the snack representation on Home.
struct TasksView: View {
    @Environment(DataStore.self) private var store

    @State private var filter: TaskFilter = .active
    @State private var editingTask: TaskItem?
    @State private var presentedMoment: MomentRoute?
    @State private var showAddTask: Bool = false

    private enum TaskFilter: String, CaseIterable {
        case active = "Active"
        case all = "All"
    }

    var body: some View {
        let groups = store.openTasksGroupedByDay()
        let completed = store.completedTasks()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                titleRow
                filterPicker
                taskList(groups: groups, completed: completed)
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
                presentedMoment = MomentRoute(id: id)
            })
            .environment(store)
        }
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id)
                .environment(store)
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet().environment(store)
        }
    }

    // MARK: - Header

    private var actionRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            addButton
        }
    }

    private var titleRow: some View {
        Text("Tasks")
            .font(Theme.greeting())
            .foregroundStyle(Theme.primaryText)
            .lineSpacing(-10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// List-level "+" — opens `AddTaskSheet` for typed task entry.
    private var addButton: some View {
        Button {
            showAddTask = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
    }

    // MARK: - Filter

    private var filterPicker: some View {
        HStack(spacing: 0) {
            ForEach(TaskFilter.allCases, id: \.self) { option in
                let isSelected = filter == option
                Text(option.rawValue)
                    .font(Theme.bodyM().weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            Capsule(style: .continuous).fill(Theme.accent)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                    .onTapGesture { withAnimation(.snappy) { filter = option } }
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(Theme.glassFill))
        .overlay(Capsule(style: .continuous).stroke(Theme.glassStroke, lineWidth: Theme.cardStrokeWidth))
    }

    // MARK: - List

    @ViewBuilder
    private func taskList(groups: [TaskDayGroup], completed: [TaskItem]) -> some View {
        if groups.isEmpty && (filter == .active || completed.isEmpty) {
            Text("All clear — no open tasks.")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups) { group in
                    daySection(label: dayLabel(group.day), tasks: group.tasks)
                }
                if filter == .all && !completed.isEmpty {
                    daySection(label: "Completed", tasks: completed)
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
                            provenance: "",
                            onToggle: { withAnimation(.snappy) { store.toggle(task) } },
                            onTapBody: { editingTask = task }
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
            withAnimation(.snappy) { store.toggle(task) }
        } label: {
            Label(
                task.status == .done ? "Mark as not done" : "Complete",
                systemImage: task.status == .done ? "arrow.uturn.left" : "checkmark.circle"
            )
        }
        Button {
            editingTask = task
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive) {
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
    TasksView()
        .background(Theme.backgroundGradient)
        .environment(DataStore.seeded(now: Date()))
}
