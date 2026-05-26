import SwiftUI

struct HomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedMoment: MomentRoute?
    @State private var presentedDetail: HomeDetailRoute?

    var ambient: AmbientState = .mock

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                tasksSection
                resurfacedSection
                journalSection
                notesSection
                recentMomentsSection
                peopleSection
                placesSection
                themesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, Theme.pageContentBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id)
                .environment(store)
        }
        .sheet(item: $presentedDetail) { route in
            switch route {
            case .person(let id):
                PersonDetailSheet(personID: id).environment(store)
            case .place(let p):
                PlaceDetailSheet(place: p).environment(store)
            case .theme(let t):
                ThemeDetailSheet(theme: t).environment(store)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateTitleFormatter.string(from: Date()))
                .font(Theme.displayMedium())
                .foregroundStyle(Theme.primaryText)

            HStack(spacing: 6) {
                Image(systemName: ambient.weather.systemImage)
                    .font(.system(size: 13, weight: .regular))
                Text("\(ambient.highTempF)° / \(ambient.lowTempF)°")
                    .font(Theme.caption())
                Text("·")
                    .font(Theme.caption())
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .regular))
                Text(ambient.city)
                    .font(Theme.caption())
            }
            .foregroundStyle(Theme.secondaryText)
        }
    }

    private static let dateTitleFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt
    }()

    @ViewBuilder
    private var tasksSection: some View {
        let openTasks = store.openTasks()
        sectionFrame(eyebrow: "Tasks") {
            if openTasks.isEmpty {
                Card {
                    Text("All clear — nothing waiting on you.")
                        .font(Theme.bodyL())
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
    private var journalSection: some View {
        let journals = store.recentJournals()
        if !journals.isEmpty {
            sectionFrame(eyebrow: "Journal") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(journals) { moment in
                            Button(action: whenIdle {
                                presentedMoment = MomentRoute(id: moment.id)
                            }) {
                                JournalCard(moment: moment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
                .capturesHorizontalSwipe()
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        let notes = store.recentNotes()
        if !notes.isEmpty {
            sectionFrame(eyebrow: "Notes") {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(notes) { note in
                        Button(action: whenIdle {
                            presentedMoment = MomentRoute(id: note.id)
                        }) {
                            NoteCard(moment: note)
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

    @ViewBuilder
    private var peopleSection: some View {
        let people = store.people
        if !people.isEmpty {
            sectionFrame(eyebrow: "People") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(people) { person in
                            PersonAvatar(person: person, onTap: whenIdle {
                                presentedDetail = .person(person.id)
                            })
                        }
                    }
                    .padding(.vertical, 4)
                }
                .capturesHorizontalSwipe()
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private var placesSection: some View {
        let places = store.places
        if !places.isEmpty {
            sectionFrame(eyebrow: "Places") {
                ChipFlow(items: places, systemImage: "location.fill", onTap: whenIdleString { place in
                    presentedDetail = .place(place)
                })
            }
        }
    }

    @ViewBuilder
    private var themesSection: some View {
        let themes = store.themes
        if !themes.isEmpty {
            sectionFrame(eyebrow: "Themes") {
                ChipFlow(items: themes, onTap: whenIdleString { theme in
                    presentedDetail = .theme(theme)
                })
            }
        }
    }

    // MARK: - Helpers

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

    private func provenance(for task: TaskItem) -> String {
        guard let moment = store.sourceMoment(of: task) else { return "" }
        return RelativeDay.label(from: moment.createdAt)
    }

    /// Wrap a tap action so it only fires when no gesture is in progress.
    private func whenIdle(_ action: @escaping () -> Void) -> () -> Void {
        return {
            guard gesturePhase == .idle else { return }
            action()
        }
    }

    /// String-parameterized variant for ChipFlow's per-chip callback.
    private func whenIdleString(_ action: @escaping (String) -> Void) -> (String) -> Void {
        return { value in
            guard gesturePhase == .idle else { return }
            action(value)
        }
    }
}

#Preview {
    HomeView()
        .environment(DataStore.seeded(now: Date()))
}
