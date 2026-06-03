import SwiftUI

struct HomeView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @Environment(\.openURL) private var openURL
    @State private var presentedMoment: MomentRoute?
    @State private var presentedTask: TaskRoute?
    @State private var presentedDetail: HomeDetailRoute?
    @State private var presentedSeeAll: SeeAllRoute?
    @State private var presentedMomentsTimeline: Bool = false
    @State private var presentedTasksTimeline: Bool = false
    @State private var presentedChatsTimeline: Bool = false
    @State private var presentedChat: ChatRoute?
    @State private var presentedRecapDay: RecapDayRoute?

    // MARK: Hardware reveal

    /// Vertical offset of the home/hardware filmstrip. `0` = Home fully
    /// shown (default); `viewportHeight` = hardware area fully shown. The
    /// hardware panel lives one screen *above* Home; pulling down drives
    /// this toward `viewportHeight`, swiping up drives it back to `0`.
    @State private var revealOffset: CGFloat = 0
    /// True while a reveal drag is actively driving `revealOffset` — locks
    /// Home's own scroll so the two don't fight.
    @State private var isRevealing = false
    @State private var homeAtTop = true
    @State private var viewportHeight: CGFloat = 0
    @State private var dragStarted = false
    @State private var dragMode: RevealDragMode = .none
    @State private var showProfile = false

    private enum RevealDragMode { case none, toHardware, toHome }

    /// Fraction of a viewport the user must pull (or fling) past to commit
    /// the snap — a *light* pull is enough.
    private let commitFraction: CGFloat = 0.15

    var ambient: AmbientState = .mock
    /// Colorway preference, surfaced in the Profile sheet.
    @Binding var appearance: AppearanceMode
    /// Which lens the Mirror presents, surfaced in the Profile sheet.
    @Binding var mirrorLens: MirrorLens

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack(alignment: .top) {
                homeScroll(viewport: h, width: w)
                    .clipped()
                    .offset(y: revealOffset)

                NecklaceHardwareView(ambient: ambient, isExpanded: revealOffset >= h - 0.5)
                    .frame(width: w, height: h, alignment: .top)
                    .clipped()
                    .offset(y: revealOffset - h)
            }
            .frame(width: w, height: h, alignment: .top)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(revealDrag(viewport: h))
            .onAppear { viewportHeight = h }
            .onChange(of: h) { _, newValue in viewportHeight = newValue }
        }
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
        .sheet(item: $presentedSeeAll) { route in
            SeeAllSheet(route: route)
                .environment(store)
        }
        .sheet(isPresented: $presentedMomentsTimeline) {
            MomentsView()
                .environment(store)
                .presentationDetents([.large])
                .presentationBackground(Theme.backgroundGradient)
        }
        .sheet(isPresented: $presentedTasksTimeline) {
            TasksView()
                .environment(store)
                .presentationDetents([.large])
                .presentationBackground(Theme.backgroundGradient)
        }
        .sheet(isPresented: $presentedChatsTimeline) {
            ChatsTimelineSheet(onSelectChat: { chatID in
                presentedChatsTimeline = false
                // Wait for the sheet to finish dismissing before stacking
                // the chat detail — iOS won't present two sheets owned by
                // the same view simultaneously.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    presentedChat = ChatRoute(id: chatID)
                }
            })
            .environment(store)
            .presentationDetents([.large])
            .presentationBackground(Theme.backgroundGradient)
        }
        .sheet(item: $presentedChat) { route in
            ChatDetailSheet(chatID: route.id).environment(store)
        }
        .sheet(item: $presentedRecapDay) { route in
            DayRecapDetailSheet(day: route.day).environment(store)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet(userInitial: ambient.userInitial, appearance: $appearance, mirrorLens: $mirrorLens)
        }
    }

    // MARK: - Home scroll

    private func homeScroll(viewport h: CGFloat, width w: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                homeColumn
                    .frame(width: w)
                    .id(Self.scrollTopID)
            }
            .frame(width: w, height: h)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollDisabled(isRevealing || revealOffset > 0.5 || gesturePhase == .horizontalSwipe)
            .onScrollGeometryChange(for: Bool.self, of: { $0.contentOffset.y <= 0 }) { _, atTop in
                homeAtTop = atTop
            }
        }
    }

    private static let scrollTopID = "home-scroll-top"

    // MARK: - Reveal gesture

    /// Drives the interactive peek-and-snap between Home and the hardware
    /// area. Engages only on a vertical pull at the relevant edge (Home's
    /// top, or anywhere on the hardware panel) so it never competes with
    /// Home's scroll or the pager's horizontal swipe.
    private func revealDrag(viewport h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dy = value.translation.height
                let dx = value.translation.width

                if !dragStarted {
                    dragStarted = true
                    let mostlyVertical = abs(dy) > abs(dx)
                    if revealOffset <= 0.5, homeAtTop, dy > 0, mostlyVertical {
                        dragMode = .toHardware
                    } else if revealOffset >= h - 0.5, dy < 0, mostlyVertical {
                        dragMode = .toHome
                    } else {
                        dragMode = .none
                    }
                }

                switch dragMode {
                case .toHardware:
                    isRevealing = true
                    revealOffset = resist(dy, limit: h)
                case .toHome:
                    isRevealing = true
                    revealOffset = h - resist(-dy, limit: h)
                case .none:
                    break
                }
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.height
                switch dragMode {
                case .toHardware:
                    let commit = revealOffset > h * commitFraction || predicted > h * 0.3
                    snap(to: commit ? h : 0)
                case .toHome:
                    let commit = revealOffset < h * (1 - commitFraction) || predicted < -h * 0.3
                    snap(to: commit ? 0 : h)
                case .none:
                    break
                }
                dragStarted = false
                dragMode = .none
                isRevealing = false
            }
    }

    /// Light rubber-band easing — eases toward `limit` so the pull has a
    /// tactile stretch, while a short pull still clears the commit
    /// threshold and snaps.
    private func resist(_ x: CGFloat, limit: CGFloat) -> CGFloat {
        guard x > 0 else { return 0 }
        return limit * (1 - 1 / (x / (limit * 0.55) + 1))
    }

    private func snap(to target: CGFloat) {
        let changed = abs(target - revealOffset) > 0.5
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            revealOffset = target
        }
        if changed {
            Haptics.settle()
        }
    }

    /// Programmatic reveal used by the necklace pill tap.
    private func revealHardware() {
        snap(to: viewportHeight)
    }

    // MARK: - Home column (the page content below the hardware area)

    private var homeColumn: some View {
        VStack(alignment: .leading, spacing: 28) {
            topBar
            mirrorSection
            tasksOverviewSection
            recapSection
            chatsSection
            peopleSection
            placesSection
            themesSection
        }
        .padding(.horizontal, 24)
        .padding(.top, Theme.pageContentTopInset)
        .padding(.bottom, Theme.pageContentBottomInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Top bar (greeting + necklace pill)

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: -10) {
                    Text(greetingWords.0)
                        .font(Theme.greeting())
                        .foregroundStyle(Theme.primaryText)
                    Text(greetingWords.1)
                        .font(Theme.greeting())
                        .foregroundStyle(Theme.primaryText)
                }
                Text(Self.dateTitleFormatter.string(from: Date()))
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 8)
            NecklaceProfilePill(
                ambient: ambient,
                onRevealHardware: { revealHardware() },
                onOpenProfile: { showProfile = true }
            )
            .padding(.top, 6)
        }
    }

    private var greeting: String {
        "\(greetingWords.0) \(greetingWords.1)"
    }

    /// Two-word greeting split into its words so the topBar can stack
    /// them in a VStack with negative spacing — `.lineSpacing(-N)` on a
    /// single Text isn't reliable enough to fully collapse Aguila's
    /// natural leading at display sizes.
    private var greetingWords: (String, String) {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return ("Good", "morning")
        case 12..<17: return ("Good", "afternoon")
        case 17..<21: return ("Good", "evening")
        default:      return ("Good", "night")
        }
    }

    private static let dateTitleFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMMM d"
        return fmt
    }()

    // MARK: - Mirror (daily summary + AI-surfaced suggestions)

    /// The "Mirror" — Taya reflecting the day back to you, directly under the
    /// topBar with no eyebrow. A lead line in Taya's voice plus a relevant
    /// surface, swapped by `mirrorLens` (a preview control in Profile).
    /// `reflection` is the default: the daily summary + the nearest open tasks.
    private var mirrorSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            lensContent
        }
        .animation(.snappy, value: mirrorLens)
    }

    @ViewBuilder
    private var lensContent: some View {
        if mirrorLens == .forYou {
            forYouLens
        } else {
            mirrorLead(MirrorNarrator.lead(for: mirrorLens, store: store))
            switch mirrorLens {
            case .reflection: tasksCard(limit: 2)
            case .focus:      tasksCard(limit: 4)
            case .revisit:    revisitCard
            case .people:     peopleLensRow
            case .themes:     themesLensFlow
            case .forYou:     EmptyView()
            }
        }
    }

    private func mirrorLead(_ text: String) -> some View {
        Text(text)
            .font(Theme.summary())
            .foregroundStyle(Theme.primaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Surfaced open tasks, capped at `limit`. Shared by the Reflection and
    /// Focus lenses (which differ only in how many they show).
    @ViewBuilder
    private func tasksCard(limit: Int) -> some View {
        let surfaced = store.homeTasks(openLimit: limit)
        if !surfaced.isEmpty {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(surfaced.enumerated()), id: \.element.id) { index, task in
                        TaskRow(
                            task: task,
                            onToggle: whenIdle {
                                Haptics.toggle()
                                withAnimation(.snappy) { store.toggle(task) }
                            },
                            onTapBody: whenIdle {
                                Haptics.tap()
                                presentedTask = TaskRoute(id: task.id)
                            }
                        )
                        .padding(.horizontal, 14)
                        if index < surfaced.count - 1 {
                            Divider()
                                .padding(.horizontal, 14)
                                .overlay(Theme.glassStroke)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    /// Older moments worth revisiting; falls back to the most recent captures
    /// when nothing has aged into the resurfaced heuristic yet.
    @ViewBuilder
    private var revisitCard: some View {
        let resurfaced = store.resurfaced()
        let moments = resurfaced.isEmpty ? store.recentMoments(limit: 2) : resurfaced
        if !moments.isEmpty {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                        Button(action: whenIdle {
                            presentedMoment = MomentRoute(ids: moments.map(\.id), startID: moment.id)
                        }) {
                            MomentRow(moment: moment)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if index < moments.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                                .overlay(Theme.glassStroke)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var peopleLensRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.people) { person in
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

    private var themesLensFlow: some View {
        ChipFlow(items: store.themes, onTap: whenIdleString { theme in
            presentedDetail = .theme(theme)
        })
    }

    // MARK: - "For you" lens (Taya's proactive work)

    /// Suggestions Taya has done work on — each a conversational lead plus a
    /// set of options the user can prune. Low-pressure by design: the only
    /// action is to dismiss what doesn't fit.
    @ViewBuilder
    private var forYouLens: some View {
        // One suggestion at a time — dismissing it reveals the next.
        if let suggestion = store.suggestions.first {
            suggestionBlock(suggestion)
        } else {
            mirrorLead("Nothing needs you right now — I'll surface things here as they come up.")
        }
    }

    private func suggestionBlock(_ suggestion: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            mirrorLead(suggestion.lead)
            VStack(spacing: 8) {
                ForEach(suggestion.options) { option in
                    optionCard(option, in: suggestion)
                }
            }
        }
    }

    private func optionCard(_ option: SuggestionOption, in suggestion: Suggestion) -> some View {
        HStack(spacing: 12) {
            // Tapping the body opens where the option leads (e.g. OpenTable).
            Button(action: whenIdle {
                if let url = option.url { openURL(url) }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.homeIcon)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.title)
                            .font(Theme.bodyL())
                            .foregroundStyle(Theme.primaryText)
                            .multilineTextAlignment(.leading)
                        Text(option.subtitle)
                            .font(Theme.bodyS())
                            .foregroundStyle(Theme.secondaryText)
                        Text(option.detail)
                            .font(Theme.caption())
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(option.url == nil)
            .accessibilityLabel("Open \(option.title)")

            Button(action: whenIdle {
                withAnimation(.snappy) { store.dismissOption(option, from: suggestion) }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss \(option.title)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .tayaGlassCard(in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    // MARK: - Tasks overview

    /// Broader open-task list — the user's standing work, surfaced as
    /// its own section under Mirror so the Mirror's curated picks have
    /// a clear "everything else" sibling. See-all links to the Tasks
    /// tab eventually.
    @ViewBuilder
    private var tasksOverviewSection: some View {
        let rows = store.homeTasks()
        if !rows.isEmpty {
            sectionFrame(eyebrow: "Tasks", onSeeAll: whenIdle { presentedTasksTimeline = true }) {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, task in
                            TaskRow(
                                task: task,
                                onToggle: whenIdle {
                                    Haptics.toggle()
                                    withAnimation(.snappy) { store.toggle(task) }
                                },
                                onTapBody: whenIdle {
                                    Haptics.tap()
                                    presentedTask = TaskRoute(id: task.id)
                                }
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

    // MARK: - Sections (existing content)

    // MARK: - Recaps

    /// Horizontal carousel of recent days. Today is the resting card on the
    /// trailing edge; older days extend off-screen to the left. Each card is
    /// full width and paged so swipes snap with "gravity." Replaces the prior
    /// day-strip + inline prose, which read too heavy on a glance surface.
    @ViewBuilder
    private var recapSection: some View {
        let days = store.recapDays(count: 14) // oldest → newest
        let recaps = days.map { store.recap(for: $0) }
        let visible = recaps.filter { $0.hasActivity || Calendar.current.isDateInToday($0.day) }

        if !visible.isEmpty {
            sectionFrame(eyebrow: "Recaps", onSeeAll: whenIdle {
                presentedRecapDay = RecapDayRoute(day: visible.last?.day ?? Date())
            }) {
                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(visible, id: \.day) { recap in
                                Button(action: whenIdle {
                                    presentedRecapDay = RecapDayRoute(day: recap.day)
                                }) {
                                    recapCard(for: recap)
                                }
                                .buttonStyle(.plain)
                                .disabled(!recap.hasActivity)
                                .frame(width: geo.size.width)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .defaultScrollAnchor(.trailing)
                    .capturesHorizontalSwipe()
                    // Let the glass cards' drop shadows extend beyond the
                    // horizontal scroll frame instead of being chopped at
                    // the page edges.
                    .scrollClipDisabled()
                }
                .frame(height: 220)
            }
        }
    }

    @ViewBuilder
    private func recapCard(for recap: DayRecap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(RelativeDay.sectionLabel(from: recap.day))
                .font(Theme.titleS())
                .foregroundStyle(Theme.primaryText)

            if recap.hasActivity, !recap.summary.isEmpty {
                Text(recap.summary)
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text("Day's not over — capture a moment to start your recap.")
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(height: 220, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tayaGlassCard(in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
    }

    @ViewBuilder
    private var chatsSection: some View {
        let chats = store.recentChats()
        if !chats.isEmpty {
            sectionFrame(eyebrow: "Chats", onSeeAll: whenIdle { presentedChatsTimeline = true }) {
                PastChatsList(chats: chats) { id in
                    presentedChat = ChatRoute(id: id)
                }
            }
        }
    }

    @ViewBuilder
    private var peopleSection: some View {
        let people = store.people
        if !people.isEmpty {
            sectionFrame(eyebrow: "People", onSeeAll: whenIdle { presentedSeeAll = .people }) {
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
            sectionFrame(eyebrow: "Places", onSeeAll: whenIdle { presentedSeeAll = .places }) {
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
            sectionFrame(eyebrow: "Themes", onSeeAll: whenIdle { presentedSeeAll = .themes }) {
                ChipFlow(items: themes, onTap: whenIdleString { theme in
                    presentedDetail = .theme(theme)
                })
            }
        }
    }

    // MARK: - Helpers

    private func sectionFrame<Content: View>(
        eyebrow: String,
        onSeeAll: (() -> Void)? = nil,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow)
                    .font(Theme.titleS())
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 8)
                if let onSeeAll {
                    Button(action: onSeeAll) {
                        Text("See all")
                            .font(Theme.bodyS())
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("See all \(eyebrow.lowercased())")
                }
            }
            content()
        }
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
    HomeView(appearance: .constant(.auto), mirrorLens: .constant(.reflection))
        .background(Theme.backgroundGradient)
        .environment(DataStore.seeded(now: Date()))
}
