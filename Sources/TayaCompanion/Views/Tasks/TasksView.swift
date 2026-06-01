import SwiftUI
import TayaIntelligence

/// Tasks timeline — the full list of open and completed tasks, grouped by
/// day, with a filter pill (Active / All) and a list-level "+" in the
/// header for manual entry. Presented as a sheet from Home's "Tasks — See
/// all" affordance now that the tab bar is gone.
struct TasksView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var filter: TaskFilter = .active
    @State private var editingTask: TaskItem?
    @State private var presentedMoment: MomentRoute?
    @State private var showAddTask: Bool = false
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    private enum TaskFilter: String, CaseIterable {
        case active = "Active"
        case all = "All"
    }

    var body: some View {
        let groups = store.openTasksGroupedByDay()
        let completed = store.completedTasks()
        VStack(spacing: 0) {
            tasksHeader
            filterPicker
            taskList(groups: groups, completed: completed)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
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

    private var tasksHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Tasks")
                .font(Theme.greeting())
                .foregroundStyle(Theme.primaryText)
            Spacer()
            #if os(iOS)
            reorderButton
            #endif
            addButton
            Button("Done") { dismiss() }
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, Theme.pageContentTopInset)
        .padding(.bottom, 12)
    }

    /// List-level "+" — opens `AddTaskSheet` for typed task entry now
    /// that the global + menu is gone.
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

    #if os(iOS)
    private var reorderButton: some View {
        Button {
            withAnimation { editMode = editMode.isEditing ? .inactive : .active }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(editMode.isEditing ? Theme.accent : Theme.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(editMode.isEditing ? "Done reordering" : "Reorder tasks")
    }
    #endif

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
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - List

    private func taskList(groups: [TaskDayGroup], completed: [TaskItem]) -> some View {
        let list = List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.tasks) { task in
                        taskRow(task)
                    }
                    .onMove { offsets, dest in
                        withAnimation(.snappy) {
                            store.moveOpenTask(onDay: group.day, fromOffsets: offsets, toOffset: dest)
                        }
                    }
                } header: {
                    sectionHeader(dayLabel(group.day))
                }
            }

            if filter == .all && !completed.isEmpty {
                Section {
                    ForEach(completed) { task in
                        taskRow(task).moveDisabled(true)
                    }
                } header: {
                    sectionHeader("Completed")
                }
            }

            if groups.isEmpty {
                Text("All clear — no open tasks.")
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 32, for: .scrollContent)
        #if os(iOS)
        return list.environment(\.editMode, $editMode)
        #else
        return list
        #endif
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRow(
            task: task,
            provenance: "",
            onToggle: { withAnimation(.snappy) { store.toggle(task) } },
            onTapBody: { editingTask = task }
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .tayaGlassCard(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
        .contextMenu { rowMenu(task) }
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
            .padding(.leading, 20)
            .padding(.top, 8)
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
