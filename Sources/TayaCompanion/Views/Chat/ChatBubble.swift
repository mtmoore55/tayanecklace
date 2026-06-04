import SwiftUI

/// Routing callbacks for entity taps inside a Taya reply. The host sheet
/// (`ChatSheet`, `ChatDetailSheet`, `QuickAskTayaSheet`) owns the actual
/// `.sheet(item:)` presentation; the bubble just bubbles up which entity
/// was tapped.
struct ChatBubbleActions {
    var onTapTask: (TaskItem.ID) -> Void = { _ in }
    var onTapPerson: (Person.ID) -> Void = { _ in }
    var onTapPlace: (String) -> Void = { _ in }
    var onTapMoment: (Moment.ID) -> Void = { _ in }
}

/// One message in a chat thread. User messages sit in a right-aligned
/// glass bubble; Taya replies render as plain narration text, or — when
/// the natural answer is structured — a short intro line followed by an
/// inline card of TaskRow / MomentRow / place / person rows that route to
/// the same detail sheets the rest of the app uses.
struct ChatBubble: View {
    let message: ChatMessage
    var actions: ChatBubbleActions = ChatBubbleActions()

    @Environment(DataStore.self) private var store

    var body: some View {
        switch message.role {
        case .user:
            HStack(alignment: .top) {
                Spacer(minLength: 40)
                userBubble
            }
        case .taya:
            tayaContent
        }
    }

    private var userBubble: some View {
        Text(message.text)
            .font(Theme.bodyL())
            .foregroundStyle(Theme.primaryText)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .tayaGlassCard(
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
    }

    @ViewBuilder
    private var tayaContent: some View {
        switch message.content {
        case .text(let s):
            tayaText(s)
        case .tasks(let intro, let ids):
            tayaList(intro: intro) { taskList(ids: ids) }
        case .places(let intro, let names):
            tayaList(intro: intro) { placeList(names: names) }
        case .people(let intro, let ids):
            tayaList(intro: intro) { personList(ids: ids) }
        case .moments(let intro, let ids):
            tayaList(intro: intro) { momentList(ids: ids) }
        }
    }

    private func tayaText(_ s: String) -> some View {
        Text(s)
            .font(Theme.bodyL())
            .foregroundStyle(Theme.primaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tayaList<Body: View>(intro: String?, @ViewBuilder body: () -> Body) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let intro, !intro.isEmpty {
                tayaText(intro)
            }
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tasks

    @ViewBuilder
    private func taskList(ids: [TaskItem.ID]) -> some View {
        let tasks = ids.compactMap { id in store.tasks.first(where: { $0.id == id }) }
        if tasks.isEmpty {
            emptyListNote("No tasks to show.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(
                            task: task,
                            onToggle: { store.toggle(task) },
                            onTapBody: { actions.onTapTask(task.id) }
                        )
                        .padding(.horizontal, 12)
                        if index < tasks.count - 1 { rowDivider }
                    }
                }
            }
        }
    }

    // MARK: - Places

    @ViewBuilder
    private func placeList(names: [String]) -> some View {
        if names.isEmpty {
            emptyListNote("No places to show.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(names.enumerated()), id: \.element) { index, place in
                        listRow(
                            leading: glyphCircle(systemImage: "location.fill"),
                            title: place,
                            subtitle: placeSubtitle(place)
                        ) {
                            actions.onTapPlace(place)
                        }
                        if index < names.count - 1 { rowDivider }
                    }
                }
            }
        }
    }

    private func placeSubtitle(_ place: String) -> String? {
        let n = store.moments(at: place).count
        guard n > 0 else { return nil }
        return n == 1 ? "1 moment" : "\(n) moments"
    }

    // MARK: - People

    @ViewBuilder
    private func personList(ids: [Person.ID]) -> some View {
        let people = ids.compactMap { id in store.people.first(where: { $0.id == id }) }
        if people.isEmpty {
            emptyListNote("No people to show.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        listRow(
                            leading: AnyView(
                                Text(String(person.name.prefix(1)))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 40, height: 40)
                                    .tayaInnerGlass(in: Circle())
                            ),
                            title: person.name,
                            subtitle: personSubtitle(person)
                        ) {
                            actions.onTapPerson(person.id)
                        }
                        if index < people.count - 1 { rowDivider }
                    }
                }
            }
        }
    }

    private func personSubtitle(_ person: Person) -> String? {
        let n = person.sourceMomentIDs.count
        if n > 0 { return n == 1 ? "1 mention" : "\(n) mentions" }
        return person.facts.first
    }

    // MARK: - Moments

    @ViewBuilder
    private func momentList(ids: [Moment.ID]) -> some View {
        let moments = ids.compactMap { id in store.moments.first(where: { $0.id == id }) }
        if moments.isEmpty {
            emptyListNote("No moments to show.")
        } else {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                        Button {
                            actions.onTapMoment(moment.id)
                        } label: {
                            MomentRow(moment: moment)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if index < moments.count - 1 { rowDivider }
                    }
                }
            }
        }
    }

    // MARK: - Row helpers

    private var rowDivider: some View {
        Divider()
            .padding(.horizontal, 12)
            .overlay(Theme.glassStroke.opacity(0.5))
    }

    private func glyphCircle(systemImage: String) -> AnyView {
        AnyView(
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .tayaInnerGlass(in: Circle())
        )
    }

    private func emptyListNote(_ s: String) -> some View {
        Text(s)
            .font(Theme.bodyM())
            .foregroundStyle(Theme.secondaryText)
            .padding(.vertical, 4)
    }

    private func listRow(
        leading: AnyView,
        title: String,
        subtitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.bodyL())
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
