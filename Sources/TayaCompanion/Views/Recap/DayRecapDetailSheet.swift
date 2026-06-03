import SwiftUI

/// `.sheet(item:)` identifier for the Daily Recap detail surface —
/// presented when the user taps the summary on Home.
struct RecapDayRoute: Identifiable, Hashable {
    let day: Date
    var id: Date { day }
}

/// Full per-day recap — scrollable day strip across the last 14 days,
/// plus the day's prose summary and every primitive surface (tasks
/// created/completed that day, moments, chats, people mentioned,
/// places, themes). Lives in a sheet so Home stays calm; the user opts
/// in by tapping the summary.
struct DayRecapDetailSheet: View {
    let initialDay: Date

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDay: Date
    @State private var presentedMoment: MomentRoute?
    @State private var presentedTask: TaskRoute?
    @State private var presentedDetail: HomeDetailRoute?
    @State private var presentedChat: ChatRoute?

    init(day: Date) {
        self.initialDay = day
        self._selectedDay = State(
            initialValue: Calendar.current.startOfDay(for: day)
        )
    }

    var body: some View {
        let recap = store.recap(for: selectedDay)
        ZStack(alignment: .topTrailing) {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DayPickerStrip(
                        days: store.recapDays(),
                        selectedDay: $selectedDay,
                        activityFor: { store.recap(for: $0).hasActivity },
                        layout: .scrollable
                    )

                    recapContent(recap)
                        .id(selectedDay)
                        .transition(.opacity)
                        .animation(.snappy, value: selectedDay)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)

            closeButton
                .padding(.top, 16)
                .padding(.trailing, 20)
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route)
                .environment(store)
        }
        .sheet(item: $presentedTask) { route in
            TaskDetailSheet(taskID: route.id).environment(store)
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
        .sheet(item: $presentedChat) { route in
            ChatDetailSheet(chatID: route.id).environment(store)
        }
    }

    // MARK: - Day content

    @ViewBuilder
    private func recapContent(_ recap: DayRecap) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(RelativeDay.sectionLabel(from: recap.day))
                .font(Theme.titleM())
                .foregroundStyle(Theme.primaryText)

            if recap.hasActivity {
                if !recap.summary.isEmpty {
                    Text(recap.summary)
                        .font(Theme.bodyL())
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                recapTasks(recap)
                recapMoments(recap)
                recapChats(recap)
                recapPeople(recap)
                recapPlaces(recap)
                recapThemes(recap)
            } else {
                Text("Nothing captured this day.")
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func recapTasks(_ recap: DayRecap) -> some View {
        let rows = recap.tasksCreated + recap.tasksCompleted.filter { task in
            !recap.tasksCreated.contains(where: { $0.id == task.id })
        }
        if !rows.isEmpty {
            subsection("Tasks") {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, task in
                            TaskRow(
                                task: task,
                                onToggle: { withAnimation(.snappy) { store.toggle(task) } },
                                onTapBody: { presentedTask = TaskRoute(id: task.id) }
                            )
                            .padding(.horizontal, 14)
                            if index < rows.count - 1 {
                                Divider()
                                    .padding(.horizontal, 14)
                                    .overlay(Theme.glassStroke)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recapMoments(_ recap: DayRecap) -> some View {
        if !recap.moments.isEmpty {
            subsection("Moments") {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(recap.moments.enumerated()), id: \.element.id) { index, moment in
                            Button {
                                presentedMoment = MomentRoute(
                                    ids: recap.moments.map(\.id),
                                    startID: moment.id
                                )
                            } label: {
                                MomentRow(moment: moment)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.plain)
                            if index < recap.moments.count - 1 {
                                Divider()
                                    .padding(.horizontal, 12)
                                    .overlay(Theme.cardStroke.opacity(0.5))
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recapChats(_ recap: DayRecap) -> some View {
        if !recap.chats.isEmpty {
            subsection("Chats") {
                PastChatsList(chats: recap.chats) { id in
                    presentedChat = ChatRoute(id: id)
                }
            }
        }
    }

    @ViewBuilder
    private func recapPeople(_ recap: DayRecap) -> some View {
        if !recap.people.isEmpty {
            subsection("People") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recap.people) { person in
                            PersonAvatar(person: person, onTap: {
                                presentedDetail = .person(person.id)
                            })
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private func recapPlaces(_ recap: DayRecap) -> some View {
        if !recap.places.isEmpty {
            subsection("Places") {
                ChipFlow(items: recap.places, systemImage: "location.fill", onTap: { place in
                    presentedDetail = .place(place)
                })
            }
        }
    }

    @ViewBuilder
    private func recapThemes(_ recap: DayRecap) -> some View {
        if !recap.themes.isEmpty {
            subsection("Themes") {
                ChipFlow(items: recap.themes, onTap: { theme in
                    presentedDetail = .theme(theme)
                })
            }
        }
    }

    private func subsection<Content: View>(
        _ eyebrow: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.micro())
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.tertiaryText)
            content()
        }
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}
