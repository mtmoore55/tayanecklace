import SwiftUI
import TayaIntelligence

/// Edit an existing task — rename, set/clear a due date, jump to its source
/// moment (if derived), or delete it. Opened by tapping a task row in the
/// See-all Tasks view.
struct TaskEditSheet: View {
    let task: TaskItem
    var onViewSource: (UUID) -> Void = { _ in }

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var includeDueDate: Bool
    @State private var dueDate: Date
    @FocusState private var focused: Bool

    init(task: TaskItem, onViewSource: @escaping (UUID) -> Void = { _ in }) {
        self.task = task
        self.onViewSource = onViewSource
        _text = State(initialValue: task.text)
        _includeDueDate = State(initialValue: task.dueAt != nil)
        _dueDate = State(initialValue: task.dueAt ?? Date())
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        TextField("Task", text: $text, axis: .vertical)
                            .font(Theme.bodyL())
                            .foregroundStyle(Theme.primaryText)
                            .tint(Theme.primaryText)
                            .focused($focused)
                            .frame(minHeight: 24, alignment: .top)
                    }

                    Card {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Due date")
                                    .font(Theme.bodyL())
                                    .foregroundStyle(Theme.primaryText)
                                Spacer()
                                Toggle("", isOn: $includeDueDate.animation(.snappy))
                                    .labelsHidden()
                                    .tint(Theme.accent)
                            }
                            if includeDueDate {
                                Divider()
                                    .overlay(Theme.glassStroke.opacity(0.5))
                                    .padding(.vertical, 12)
                                HStack {
                                    DatePicker("", selection: $dueDate, displayedComponents: [.date])
                                        .labelsHidden()
                                    Spacer()
                                }
                            }
                        }
                    }

                    if let source = task.originMomentID {
                        Button {
                            onViewSource(source)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "waveform")
                                Text("View source moment")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            .font(Theme.bodyL())
                            .foregroundStyle(Theme.primaryText)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tayaGlassCard(in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(role: .destructive) {
                        store.deleteTask(task)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                            Text("Delete task")
                        }
                        .font(Theme.bodyL())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .tayaGlassCard(in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Edit task")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateTask(
                            id: task.id,
                            text: text,
                            dueAt: includeDueDate ? dueDate : nil
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
    }
}

#Preview {
    let store = DataStore.seeded(now: Date())
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            if let task = store.tasks.first {
                TaskEditSheet(task: task).environment(store)
            }
        }
}
