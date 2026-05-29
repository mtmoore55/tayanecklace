import SwiftUI
import TayaIntelligence

/// The destinations each "See all" link on Home routes to. Mirrors the
/// Home sections that expose a see-all affordance.
enum SeeAllRoute: String, Identifiable, Hashable {
    case tasks, journal, notes, moments, people, places, themes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks:   return "Tasks"
        case .journal: return "Journal"
        case .notes:   return "Notes"
        case .moments: return "Moments"
        case .people:  return "People"
        case .places:  return "Places"
        case .themes:  return "Themes"
        }
    }
}

/// Bottom sheet that opens when a Home eyebrow's "See all" is tapped.
/// One view, route-driven content — reuses the same card components that
/// the Home sections render, just with no preview limit applied. Taps
/// inside fall back through `onOpenMoment` / `onOpenDetail` so the parent
/// can dismiss this sheet and present the corresponding detail.
struct SeeAllSheet: View {
    let route: SeeAllRoute
    let onOpenMoment: (UUID) -> Void
    let onOpenDetail: (HomeDetailRoute) -> Void

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var newTaskText = ""
    @FocusState private var addTaskFocused: Bool
    @State private var filter: TaskFilter = .active
    @State private var editingTask: TaskItem?
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    private enum TaskFilter: String, CaseIterable {
        case active = "Active"
        case all = "All"
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            if route == .tasks {
                tasksScreen
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        content
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $editingTask) { task in
            TaskEditSheet(task: task, onViewSource: { id in
                editingTask = nil
                onOpenMoment(id)
            })
            .environment(store)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(route.title)
                .font(Theme.displayXL())
                .foregroundStyle(Theme.primaryText)
            Spacer()
            Button("Done") { dismiss() }
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .tasks:   EmptyView()   // handled by `tasksScreen` in `body`
        case .journal: journalList
        case .notes:   notesList
        case .moments: momentsList
        case .people:  peopleList
        case .places:  placesList
        case .themes:  themesList
        }
    }

    // MARK: - Tasks screen

    private var tasksScreen: some View {
        let groups = store.openTasksGroupedByDay()
        let completed = store.completedTasks()
        return VStack(spacing: 0) {
            tasksHeader
            filterPicker
            taskList(groups: groups, completed: completed)
        }
        .safeAreaInset(edge: .bottom) { addTaskBar }
    }

    private var tasksHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Tasks")
                .font(Theme.displayXL())
                .foregroundStyle(Theme.primaryText)
            Spacer()
            #if os(iOS)
            reorderButton
                .padding(.trailing, 4)
            #endif
            Button("Done") { dismiss() }
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
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

    private var canAddTask: Bool {
        !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var addTaskBar: some View {
        HStack(spacing: 10) {
            TextField("Add a task", text: $newTaskText)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .tint(Theme.primaryText)
                .focused($addTaskFocused)
                .submitLabel(.done)
                .onSubmit(submitNewTask)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(Capsule(style: .continuous).fill(Theme.glassFillStrong))
                .overlay(Capsule(style: .continuous).stroke(Theme.glassStrokeStrong, lineWidth: 0.75))

            Button(action: submitNewTask) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(canAddTask ? Theme.accent : Theme.accent.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .disabled(!canAddTask)
            .accessibilityLabel("Add task")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background {
            // Opaque backing so the scrolling task list doesn't bleed
            // through the input bar; a hairline at the top separates the
            // bar from the list it floats above.
            Theme.background
                .opacity(0.97)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.glassStroke)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func submitNewTask() {
        guard canAddTask else { return }
        let text = newTaskText
        newTaskText = ""
        withAnimation(.snappy) { store.addTask(text) }
        addTaskFocused = true
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Journal (every kind: .journal moment, newest first)

    private var journalList: some View {
        let journals = store.moments
            .filter { $0.kind == .journal }
            .sorted { $0.createdAt > $1.createdAt }
        return VStack(spacing: 12) {
            ForEach(journals) { moment in
                Button {
                    onOpenMoment(moment.id)
                } label: {
                    JournalCard(moment: moment)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notes (every kind: .note)

    private var notesList: some View {
        let notes = store.moments
            .filter { $0.kind == .note }
            .sorted { $0.createdAt > $1.createdAt }
        return LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(notes) { note in
                Button {
                    onOpenMoment(note.id)
                } label: {
                    NoteCard(moment: note)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Moments (every kind: .voice raw moment)

    private var momentsList: some View {
        let all = store.moments
            .filter { $0.kind == .voice }
            .sorted { $0.createdAt > $1.createdAt }
        return Card(padding: 4) {
            VStack(spacing: 0) {
                ForEach(Array(all.enumerated()), id: \.element.id) { index, moment in
                    Button {
                        onOpenMoment(moment.id)
                    } label: {
                        MomentRow(moment: moment)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)
                    if index < all.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                            .overlay(Theme.cardStroke.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - People

    private var peopleList: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 16
        ) {
            ForEach(store.people) { person in
                PersonAvatar(person: person, onTap: {
                    onOpenDetail(.person(person.id))
                })
            }
        }
    }

    // MARK: - Places

    private var placesList: some View {
        ChipFlow(items: store.places, systemImage: "location.fill", onTap: { place in
            onOpenDetail(.place(place))
        })
    }

    // MARK: - Themes

    private var themesList: some View {
        ChipFlow(items: store.themes, onTap: { theme in
            onOpenDetail(.theme(theme))
        })
    }
}
