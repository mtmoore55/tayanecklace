import SwiftUI

/// Tasks timeline — the full list of open (and today's completed)
/// tasks, presented as a sheet from Home. Renders as a single
/// connected glass card with no day grouping; history lives in a
/// dedicated stacked sheet reached via the clock icon.
struct TasksView: View {
    @Environment(DataStore.self) private var store

    @State private var sort: TaskSort = .manual
    @State private var hideCompletedToday: Bool = false
    @State private var editingTask: TaskItem?
    @State private var presentedMoment: MomentRoute?
    @State private var showAddTask: Bool = false
    @State private var showHistory: Bool = false
    @State private var showRecentlyDeleted: Bool = false
    @State private var confirmClearCompleted: Bool = false

    enum TaskSort: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case due    = "Due date"
        case created = "Recently added"
        var id: String { rawValue }
    }

    var body: some View {
        let rows = visibleRows()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                titleRow
                taskList(rows: rows)
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
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet().environment(store)
        }
        .sheet(isPresented: $showHistory) {
            TaskHistorySheet().environment(store)
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
            circleButton(systemImage: "plus", label: "Add task") {
                Haptics.tap()
                showAddTask = true
            }
            circleButton(systemImage: "clock.arrow.circlepath", label: "Archive") {
                Haptics.tap()
                showHistory = true
            }
            ellipsisMenuButton
        }
    }

    private var titleRow: some View {
        Text("Tasks")
            .font(Theme.greeting())
            .foregroundStyle(Theme.primaryText)
            .lineSpacing(-10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func circleButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var ellipsisMenuButton: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(TaskSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            Toggle(isOn: $hideCompletedToday) {
                Label("Hide completed today", systemImage: "eye.slash")
            }
            Divider()
            Button {
                Haptics.tap()
                showRecentlyDeleted = true
            } label: {
                Label("Recently deleted", systemImage: "trash.slash")
            }
            Button(role: .destructive) {
                Haptics.warning()
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

    // MARK: - List

    @ViewBuilder
    private func taskList(rows: [TaskItem]) -> some View {
        if rows.isEmpty {
            Text("All clear — no open tasks.")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, task in
                        TaskRow(
                            task: task,
                            onToggle: {
                                Haptics.toggle()
                                withAnimation(.snappy) { store.toggle(task) }
                            },
                            onTapBody: {
                                Haptics.tap()
                                editingTask = task
                            },
                            onDelete: {
                                withAnimation(.snappy) { store.deleteTask(task) }
                            }
                        )
                        .padding(.horizontal, 12)
                        .contextMenu { rowMenu(task) }
                        if index < rows.count - 1 {
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
            Label(
                task.status == .done ? "Mark as not done" : "Complete",
                systemImage: task.status == .done ? "arrow.uturn.left" : "checkmark.circle"
            )
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

    // MARK: - Data

    private func visibleRows() -> [TaskItem] {
        let open = sortedOpen()
        if hideCompletedToday { return open }
        return open + store.tasksCompletedToday()
    }

    private func sortedOpen() -> [TaskItem] {
        let open = store.openTasks()
        switch sort {
        case .manual:
            return open
        case .due:
            return open.sorted { lhs, rhs in
                switch (lhs.dueAt, rhs.dueAt) {
                case let (l?, r?): return l < r
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return lhs.createdAt < rhs.createdAt
                }
            }
        case .created:
            return open.sorted { $0.createdAt > $1.createdAt }
        }
    }
}

#Preview {
    TasksView()
        .background(Theme.backgroundGradient)
        .environment(DataStore.seeded(now: Date()))
}
