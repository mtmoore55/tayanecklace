import SwiftUI

/// Quick task entry — typed directly in the app, no voice capture needed.
/// A text field plus an optional due date; Save creates an open `TaskItem`
/// with no source moment.
struct AddTaskSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var includeDueDate = false
    @State private var dueDate = Date()
    @FocusState private var isFocused: Bool

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                header

                Card {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("What needs doing?")
                                .font(Theme.bodyL())
                                .foregroundStyle(Theme.primaryText.opacity(0.7))
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $text, axis: .vertical)
                            .font(Theme.bodyL())
                            .foregroundStyle(Theme.primaryText)
                            .tint(Theme.primaryText)
                            .focused($isFocused)
                            .frame(minHeight: 24, alignment: .top)
                    }
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
                                .overlay(Theme.glassStroke)
                                .padding(.vertical, 12)
                            HStack {
                                DatePicker(
                                    "",
                                    selection: $dueDate,
                                    displayedComponents: [.date]
                                )
                                .labelsHidden()
                                .tint(Theme.accent)
                                Spacer()
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .onAppear { isFocused = true }
    }

    private var header: some View {
        ZStack {
            Text("New task")
                .font(Theme.titleS())
                .foregroundStyle(Theme.primaryText)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Button {
                    store.addTask(text, dueAt: includeDueDate ? dueDate : nil)
                    Haptics.success()
                    dismiss()
                } label: {
                    Text("Add")
                        .font(Theme.bodyM().weight(.semibold))
                        .foregroundStyle(canSave ? Theme.onAccent : Theme.onAccent.opacity(0.75))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(canSave ? Theme.accent : Theme.accent.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .animation(.easeOut(duration: 0.18), value: canSave)
            }
        }
        .padding(.top, 22)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddTaskSheet()
                .environment(DataStore.seeded(now: Date()))
        }
}
