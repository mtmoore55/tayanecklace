import SwiftUI

struct HomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedMoment: MomentRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                tasksSection
                resurfacedSection
                recentMomentsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id)
                .environment(store)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var tasksSection: some View {
        let openTasks = store.openTasks()
        sectionFrame(eyebrow: "Tasks") {
            if openTasks.isEmpty {
                Card {
                    Text("All clear — nothing waiting on you.")
                        .font(Theme.body())
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(openTasks.enumerated()), id: \.element.id) { index, task in
                            TaskRow(
                                task: task,
                                provenance: provenance(for: task),
                                onToggle: whenIdle { store.toggle(task) },
                                onTapBody: whenIdle {
                                    presentedMoment = MomentRoute(id: task.sourceMomentID)
                                }
                            )
                            .padding(.horizontal, 12)
                            if index < openTasks.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var resurfacedSection: some View {
        let cards = store.resurfaced()
        if !cards.isEmpty {
            sectionFrame(eyebrow: "Resurfaced") {
                VStack(spacing: 12) {
                    ForEach(cards) { moment in
                        Button(action: whenIdle {
                            presentedMoment = MomentRoute(id: moment.id)
                        }) {
                            Card {
                                ResurfacedCard(moment: moment)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentMomentsSection: some View {
        let recent = store.recentMoments(limit: 5)
        sectionFrame(eyebrow: "Recent moments") {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, moment in
                        Button(action: whenIdle {
                            presentedMoment = MomentRoute(id: moment.id)
                        }) {
                            MomentRow(moment: moment)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if index < recent.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionFrame<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.eyebrow())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    private func provenance(for task: TaskItem) -> String {
        guard let moment = store.sourceMoment(of: task) else { return "" }
        return RelativeDay.label(from: moment.createdAt)
    }

    /// Wrap a tap action so it only fires when no gesture is in progress.
    /// Captures `gesturePhase` lazily so the latest value is read at tap
    /// time rather than at declaration time.
    private func whenIdle(_ action: @escaping () -> Void) -> () -> Void {
        return {
            guard gesturePhase == .idle else { return }
            action()
        }
    }
}

#Preview {
    HomeView()
        .environment(DataStore.seeded(now: Date()))
}
