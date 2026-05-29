import SwiftUI
import TayaIntelligence

struct PlaceDetailSheet: View {
    let place: String
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var presentedMoment: MomentRoute?
    @State private var askTayaQuery: String?

    var body: some View {
        content
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private var content: some View {
        let moments = store.moments(at: place)
        let tasks = openTasks(linkedTo: moments)

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(momentCount: moments.count)
                if !moments.isEmpty {
                    momentsSection(moments: moments)
                }
                if !tasks.isEmpty {
                    tasksSection(tasks: tasks)
                }
                if moments.isEmpty && tasks.isEmpty {
                    emptyState
                }
                askTayaCTA
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func openTasks(linkedTo moments: [Moment]) -> [TaskItem] {
        let ids = Set(moments.map(\.id))
        return store.tasks
            .filter { $0.status == .open && $0.sourceMomentIDs.contains(where: ids.contains) }
    }

    // MARK: - Header

    private func header(momentCount: Int) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "location.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 96, height: 96)
                .tayaGlassCard(in: Circle())

            VStack(spacing: 4) {
                Text(place)
                    .font(Theme.titleL())
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle(momentCount: momentCount))
                    .font(Theme.bodyS())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func subtitle(momentCount: Int) -> String {
        switch momentCount {
        case 0: return "No moments yet"
        case 1: return "1 moment here"
        default: return "\(momentCount) moments here"
        }
    }

    // MARK: - Sections

    private func momentsSection(moments: [Moment]) -> some View {
        sectionFrame(eyebrow: "Moments here") {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(moments.enumerated()), id: \.element.id) { i, moment in
                        Button {
                            presentedMoment = MomentRoute(id: moment.id)
                        } label: {
                            MomentRow(moment: moment)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if i < moments.count - 1 {
                            Divider().padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
    }

    private func tasksSection(tasks: [TaskItem]) -> some View {
        sectionFrame(eyebrow: "Open tasks") {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { i, task in
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(Theme.secondaryText)
                            Text(task.text)
                                .font(Theme.bodyL())
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        if i < tasks.count - 1 {
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Card {
            Text("No captured moments mention \(place) yet.")
                .font(Theme.bodyL())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var askTayaCTA: some View {
        Button {
            askTayaQuery = "What have I captured about \(place)?"
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("Ask Taya about \(place)")
                    .font(Theme.bodyL().weight(.semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule(style: .continuous).fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func sectionFrame<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }
}

private struct AskTayaSeed: Identifiable {
    let id = UUID()
    let query: String
}

#Preview {
    PlaceDetailSheet(place: "Oakland")
        .environment(DataStore.seeded(now: Date()))
}
