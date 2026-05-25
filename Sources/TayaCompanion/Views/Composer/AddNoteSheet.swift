import SwiftUI

/// Placeholder for the "Add a note manually" flow. A TextEditor for the
/// thought, plus Save/Cancel toolbar buttons. Save is stubbed — the real
/// wire-up to `DataStore.append(moment:...)` lands in Phase 3.
struct AddNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(Theme.body())
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .focused($isFocused)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Write a thought…")
                                .font(Theme.body())
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.horizontal, 22)
                                .padding(.top, 20)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .background(Theme.background)
            .navigationTitle("New note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // TODO Phase 3: append a Moment to the DataStore.
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(Theme.accent)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AddNoteSheet()
}
