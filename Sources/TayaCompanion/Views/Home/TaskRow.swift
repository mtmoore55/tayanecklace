import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let provenance: String        // e.g. "from Wed", "today"
    let onToggle: () -> Void
    let onTapBody: () -> Void     // tap the row body (not the checkbox) → source moment

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(task.status == .done ? Theme.accent : Theme.secondaryText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .done ? "Mark as not done" : "Mark as done")

            Button(action: onTapBody) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.text)
                        .font(Theme.body())
                        .foregroundStyle(task.status == .done ? Theme.secondaryText : Theme.primaryText)
                        .strikethrough(task.status == .done, color: Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text(provenance)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.secondaryText)
                        .layoutPriority(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}
