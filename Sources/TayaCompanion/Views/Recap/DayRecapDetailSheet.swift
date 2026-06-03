import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// `.sheet(item:)` identifier for the Daily Recap detail surface —
/// presented when the user taps the summary on Home.
struct RecapDayRoute: Identifiable, Hashable {
    let day: Date
    var id: Date { day }
}

/// Full per-day recap. Header row carries the "Recaps" eyebrow + a glass
/// action pill. Below it sits a scrollable day strip and a paged TabView
/// of per-day content — the day strip and the TabView selection are both
/// bound to `selectedDay`, so swiping the body advances the strip and
/// vice versa.
struct DayRecapDetailSheet: View {
    let initialDay: Date

    @Environment(DataStore.self) private var store

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
        let days = store.recapDays() // oldest → newest
        // The body VStack spans the full sheet width so the horizontal
        // scroll containers (DayPickerStrip, TabView pages) can flow
        // edge-to-edge. Each child that needs gutter respect — the
        // actionRow, surfaceTitle, and per-page content — applies its
        // own 24pt horizontal inset.
        VStack(alignment: .leading, spacing: 16) {
            actionRow
            surfaceTitle
            DayPickerStrip(
                days: days,
                selectedDay: $selectedDay,
                activityFor: { store.recap(for: $0).hasActivity },
                layout: .scrollable
            )
            TabView(selection: $selectedDay) {
                ForEach(days, id: \.self) { day in
                    dayPage(for: day)
                        .tag(day)
                }
            }
            #if !os(macOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .ignoresSafeArea(edges: .bottom)
        }
        .padding(.top, 12)
        .background(Theme.backgroundGradient.ignoresSafeArea())
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

    // MARK: - Chrome

    /// Top row: trailing-aligned ellipsis pill pinned under the drag
    /// indicator. Matches the chat sheet pattern — actions on top, big
    /// Aguila surface title beneath.
    private var actionRow: some View {
        HStack(alignment: .center) {
            Spacer(minLength: 8)
            ellipsisPill
        }
        .padding(.horizontal, 24)
    }

    private var surfaceTitle: some View {
        Text("Recaps")
            .font(Theme.greeting())
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, 24)
    }

    private var ellipsisPill: some View {
        let recap = store.recap(for: selectedDay)
        return DetailActionPill(
            modes: [],
            selectedModeID: .constant("")
        ) {
            Button {
                copy(recap.summary)
            } label: {
                Label("Copy summary", systemImage: "doc.on.doc")
            }
            .disabled(recap.summary.isEmpty)
        }
    }

    // MARK: - Day content

    private func dayPage(for day: Date) -> some View {
        let recap = store.recap(for: day)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                dayHeader(for: day)
                recapBody(recap)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .scrollContentBackground(.hidden)
        // Let the glass-card drop shadows extend beyond the scroll frame
        // rather than being clipped flat at the bottom of the visible area.
        .scrollClipDisabled()
    }

    private func dayHeader(for day: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(RelativeDay.sectionLabel(from: day))
                .font(Theme.titleM())
                .foregroundStyle(Theme.primaryText)
            Text(Self.dateSubtitle(for: day))
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    /// Date line below the Aguila title. Today/Yesterday keep the weekday
    /// prefix ("Tue · Jun 2") so the relative title has a concrete anchor;
    /// other days drop the weekday since it would just repeat the title
    /// ("Sunday" + "Sun · May 31" reads as a duplicate).
    private static func dateSubtitle(for day: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: now)
        let startOfDay = cal.startOfDay(for: day)
        let delta = cal.dateComponents([.day], from: startOfDay, to: startOfNow).day ?? 0
        let keepWeekday = (delta == 0 || delta == 1)
        let fmt = DateFormatter()
        fmt.dateFormat = keepWeekday ? "EEE · MMM d" : "MMM d"
        return fmt.string(from: day)
    }

    @ViewBuilder
    private func recapBody(_ recap: DayRecap) -> some View {
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

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        Haptics.success()
    }
}
