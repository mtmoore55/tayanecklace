import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onTapBody: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(task.status == .done ? Theme.homeIcon : Color.white.opacity(0.9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .done ? "Mark as not done" : "Mark as done")

            Button(action: onTapBody) {
                HStack(alignment: .center, spacing: 8) {
                    Text(task.text)
                        .font(Theme.bodyL())
                        .foregroundStyle(task.status == .done ? Theme.secondaryText : Theme.primaryText)
                        .strikethrough(task.status == .done, color: Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if task.status == .open, let due = task.dueAt {
                        TaskDuePill(dueAt: due)
                            .layoutPriority(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

/// Trailing pill that surfaces a task's due date. Hidden when no
/// `dueAt`. Tint encodes urgency at a glance: overdue red, today the
/// accent sky-blue, future a subtle outline.
struct TaskDuePill: View {
    let dueAt: Date
    var now: Date = Date()

    var body: some View {
        let style = Self.style(for: dueAt, now: now)
        Text(style.label)
            .font(Theme.bodyS().weight(.semibold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous).fill(style.background)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(style.stroke, lineWidth: 0.75)
            }
            .accessibilityLabel("Due \(dueAt.formatted(date: .long, time: .omitted))")
    }

    private struct Style {
        let label: String
        let foreground: Color
        let background: Color
        let stroke: Color
    }

    private static func style(for due: Date, now: Date) -> Style {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: now)
        let startDue = cal.startOfDay(for: due)
        let days = cal.dateComponents([.day], from: startToday, to: startDue).day ?? 0

        if days < 0 {
            let late = -days
            // Soft warm chip rather than solid red — the brand palette
            // tops out at `warningAmber`, and the Pending badge on
            // MomentRow already uses this exact tint pattern.
            return Style(
                label: late == 1 ? "1d late" : "\(late)d late",
                foreground: TayaColors.warningAmber,
                background: TayaColors.warningAmber.opacity(0.15),
                stroke: TayaColors.warningAmber.opacity(0.45)
            )
        }
        if days == 0 {
            return Style(
                label: "Today",
                foreground: Theme.onAccent,
                background: TayaColors.skyBlue.opacity(0.9),
                stroke: Color.white.opacity(0.25)
            )
        }
        return Style(
            label: futureLabel(for: due, days: days, now: now, cal: cal),
            foreground: Theme.secondaryText,
            background: Color.white.opacity(0.08),
            stroke: Theme.glassStroke
        )
    }

    private static func futureLabel(for due: Date, days: Int, now: Date, cal: Calendar) -> String {
        if days == 1 { return "Tomorrow" }
        if days < 7 { return due.formatted(.dateTime.weekday(.abbreviated)) }
        let sameYear = cal.component(.year, from: due) == cal.component(.year, from: now)
        return sameYear
            ? due.formatted(.dateTime.month(.abbreviated).day())
            : due.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
