import Foundation
import Observation

@Observable
@MainActor
public final class DataStore {
    public var moments: [Moment]
    public var tasks: [TaskItem]
    public var people: [Person]
    public var chats: [Chat]
    /// Proactive proposals Taya has surfaced (the "For you" Mirror lens).
    public var suggestions: [Suggestion]

    public init(
        moments: [Moment] = [],
        tasks: [TaskItem] = [],
        people: [Person] = [],
        chats: [Chat] = [],
        suggestions: [Suggestion] = []
    ) {
        self.moments = moments
        self.tasks = tasks
        self.people = people
        self.chats = chats
        self.suggestions = suggestions
    }

    public static func seeded(now: Date = Date()) -> DataStore {
        SeedData.makeStore(now: now)
    }

    // MARK: - Lookups

    public func moment(_ id: UUID) -> Moment? {
        moments.first { $0.id == id }
    }

    public func person(_ id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    public func task(_ id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }

    // MARK: - Provenance (moment ⟶ entities)

    public func tasks(from momentID: UUID) -> [TaskItem] {
        tasks.filter { $0.sourceMomentIDs.contains(momentID) }
    }

    public func people(in momentID: UUID) -> [Person] {
        people.filter { $0.sourceMomentIDs.contains(momentID) }
    }

    // MARK: - Provenance (entity ⟶ moments)

    public func moments(mentioning personID: UUID) -> [Moment] {
        guard let person = person(personID) else { return [] }
        let ids = Set(person.sourceMomentIDs)
        return moments
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func sourceMoment(of task: TaskItem) -> Moment? {
        guard let originID = task.originMomentID else { return nil }
        return moment(originID)
    }

    // MARK: - Curated views (for Home)

    /// Open tasks, oldest first — so anything carried over from prior days surfaces first.
    public func openTasks() -> [TaskItem] {
        tasks
            .filter { $0.status == .open }
            .sorted { lhs, rhs in effectiveDate(lhs) < effectiveDate(rhs) }
    }

    /// Tasks completed today, most-recently-completed first. Home keeps
    /// these visible (sunk below the open ones) so checking something off
    /// is satisfying rather than making it vanish.
    public func tasksCompletedToday(now: Date = Date()) -> [TaskItem] {
        let cal = Calendar.current
        return tasks
            .filter { $0.status == .done && cal.isDate($0.updatedAt, inSameDayAs: now) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Ordered list for Home's task surfaces: open tasks first (oldest
    /// first), then today's completed tasks at the bottom. `openLimit`
    /// caps the total rows — today's completed tasks consume slots out of
    /// the same budget. That keeps the visible window stable when you
    /// check something off: the toggled task sinks in place rather than
    /// being replaced by the next hidden open task. Pass nil from the
    /// Tasks overview to show everything.
    public func homeTasks(openLimit: Int? = nil, now: Date = Date()) -> [TaskItem] {
        let completed = tasksCompletedToday(now: now)
        let open = openTasks()
        guard let limit = openLimit else { return open + completed }
        let openBudget = max(0, limit - completed.count)
        return Array(open.prefix(openBudget)) + completed
    }

    /// Open tasks grouped by the day they surfaced (source-moment day, or
    /// the task's own creation day for manually-added ones). Most recent
    /// day first so "Today" leads. Drives the See-all Tasks view.
    /// Within each day, tasks keep their order in the backing `tasks`
    /// array — so manual drag-reordering (see `moveOpenTask`) is the source
    /// of truth, not a derived sort.
    public func openTasksGroupedByDay() -> [TaskDayGroup] {
        let cal = Calendar.current
        let open = tasks.filter { $0.status == .open }
        return Dictionary(grouping: open) { cal.startOfDay(for: effectiveDate($0)) }
            .map { day, items in TaskDayGroup(day: day, tasks: items) }
            .sorted { $0.day > $1.day }
    }

    /// All completed tasks, most-recently-completed first — the See-all
    /// "Completed" section.
    public func completedTasks() -> [TaskItem] {
        tasks
            .filter { $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The day a task belongs to — its source moment's day when derived,
    /// else its own creation day.
    private func effectiveDate(_ task: TaskItem) -> Date {
        sourceMoment(of: task)?.createdAt ?? task.createdAt
    }

    /// Recent raw voice captures. Journals have their own Home section —
    /// Moments are the bedrock unstructured stream those derive from.
    public func recentMoments(limit: Int = 5) -> [Moment] {
        moments
            .filter { $0.kind == .voice }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Recent journal entries, newest first.
    public func recentJournals(limit: Int = 6) -> [Moment] {
        moments
            .filter { $0.kind == .journal }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Unique themes — set of all tags across all moments, deduped.
    public var themes: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for tag in moments.flatMap({ $0.tags }) {
            if seen.insert(tag).inserted { out.append(tag) }
        }
        return out
    }

    /// Mock places extracted from moment narratives. Demo-grade — real
    /// extraction (CoreNLP, on-device NER) lands later. For now the list
    /// is hand-curated to match what the seed transcripts mention.
    public var places: [String] {
        ["Wildcat Canyon", "Oakland", "San Francisco", "Tartine", "True Laurel"]
    }

    /// Moments that mention a place (text match across title, summary,
    /// raw transcript). Case-insensitive.
    public func moments(at place: String) -> [Moment] {
        moments.filter { moment in
            moment.title.localizedCaseInsensitiveContains(place)
                || moment.polishedSummary.localizedCaseInsensitiveContains(place)
                || moment.rawTranscript.localizedCaseInsensitiveContains(place)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// Moments tagged with a theme (exact match on tag).
    public func moments(taggedWith theme: String) -> [Moment] {
        moments
            .filter { $0.tags.contains(theme) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// People that appear in moments tagged with a theme — used by the
    /// theme detail sheet to show "who shows up here."
    public func people(forTheme theme: String) -> [Person] {
        let momentIDs = Set(moments(taggedWith: theme).map(\.id))
        return people.filter { person in
            !Set(person.sourceMomentIDs).isDisjoint(with: momentIDs)
        }
    }

    /// Chats sorted with the most recent first — what the Chats list view
    /// renders.
    public var chatsSortedByRecency: [Chat] {
        chats.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    /// Recent chats for Home's Chats section, newest first.
    public func recentChats(limit: Int = 3) -> [Chat] {
        Array(chatsSortedByRecency.prefix(limit))
    }

    public func chat(_ id: Chat.ID) -> Chat? {
        chats.first { $0.id == id }
    }

    /// Older moments worth a second look. Heuristic: tagged `recommendation`
    /// and at least two calendar days old. Capped at two cards.
    public func resurfaced(now: Date = Date()) -> [Moment] {
        let cal = Calendar.current
        let cutoff = cal.date(
            byAdding: .day,
            value: -2,
            to: cal.startOfDay(for: now)
        ) ?? now
        return moments
            .filter { $0.createdAt < cutoff && $0.tags.contains("recommendation") }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(2)
            .map { $0 }
    }

    // MARK: - Mutations (demo-grade)

    public func toggle(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].status = tasks[idx].status == .open ? .done : .open
        tasks[idx].updatedAt = Date()
    }

    /// Drop a single option the user isn't interested in. When a suggestion
    /// runs out of options it goes away entirely.
    public func dismissOption(_ option: SuggestionOption, from suggestion: Suggestion) {
        guard let idx = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        suggestions[idx].options.removeAll { $0.id == option.id }
        if suggestions[idx].options.isEmpty {
            suggestions.remove(at: idx)
        }
    }

    /// Dismiss a whole suggestion ("not for me").
    public func dismiss(_ suggestion: Suggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
    }

    /// Create a task the user typed directly in the app (no source moment).
    /// Inserted at the front so it surfaces immediately.
    public func addTask(_ text: String, dueAt: Date? = nil, now: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.insert(
            TaskItem(text: trimmed, status: .open, dueAt: dueAt, sourceMomentIDs: [], createdAt: now),
            at: 0
        )
    }

    public func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
    }

    /// Rename and replace the fact list on an existing Person. Empty
    /// facts are dropped; an empty name is ignored so we never blank
    /// the title field. Real pipeline runs Extract → Resolve → Merge —
    /// this is the manual override path.
    public func updatePerson(id: UUID, name: String, facts: [String]) {
        guard let idx = people.firstIndex(where: { $0.id == id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { people[idx].name = trimmedName }
        people[idx].facts = facts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        people[idx].updatedAt = Date()
    }

    public func deletePerson(_ person: Person) {
        people.removeAll { $0.id == person.id }
    }

    /// Rename and/or set/clear the due date of an existing task.
    public func updateTask(id: UUID, text: String, dueAt: Date?) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { tasks[idx].text = trimmed }
        tasks[idx].dueAt = dueAt
        tasks[idx].updatedAt = Date()
    }

    /// Reorder open tasks within a single day section (drag-to-reorder in
    /// the See-all Tasks list). The section's order maps back onto the
    /// global `tasks` array so it persists.
    public func moveOpenTask(onDay day: Date, fromOffsets: IndexSet, toOffset: Int) {
        let cal = Calendar.current
        let slots = tasks.indices.filter {
            tasks[$0].status == .open && cal.isDate(effectiveDate(tasks[$0]), inSameDayAs: day)
        }
        guard !slots.isEmpty else { return }
        var dayTasks = slots.map { tasks[$0] }
        dayTasks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (slot, globalIdx) in slots.enumerated() {
            tasks[globalIdx] = dayTasks[slot]
        }
    }

    /// Append a message to an existing chat. Used by chat detail views
    /// when the user continues a conversation.
    public func appendMessage(to chatID: Chat.ID, role: ChatMessage.Role, text: String) {
        guard let idx = chats.firstIndex(where: { $0.id == chatID }) else { return }
        let message = ChatMessage(role: role, text: text, createdAt: Date())
        chats[idx].messages.append(message)
    }

    public func append(moment: Moment, extractedTasks: [TaskItem] = [], peopleMentions: [UUID] = []) {
        moments.append(moment)
        tasks.append(contentsOf: extractedTasks)
        for personID in peopleMentions {
            guard let idx = people.firstIndex(where: { $0.id == personID }) else { continue }
            if !people[idx].sourceMomentIDs.contains(moment.id) {
                people[idx].sourceMomentIDs.append(moment.id)
                people[idx].updatedAt = moment.createdAt
            }
        }
    }

    /// Drops in the two moments + one task that the first-launch sync
    /// sequence appears to have pulled off the necklace. Wired from
    /// `RootView` once the sync animation completes.
    public func appendSyncedContent(now: Date = Date()) {
        let momentA = Moment(
            createdAt: now,
            source: .necklace,
            title: "Coffee with Priya",
            rawTranscript: """
            Just bumped into Priya at Highwire. She's back from Berlin and \
            wants to grab a proper coffee next week — said she has photos and \
            stories. Should follow up before the week gets away from me.
            """,
            polishedSummary: """
            Ran into Priya — she's back from Berlin and wants to catch up next \
            week. Follow up before the week slips.
            """,
            tags: ["friends", "follow-up"]
        )

        let momentB = Moment(
            createdAt: now.addingTimeInterval(-90),
            source: .necklace,
            title: "Pick up dry cleaning",
            rawTranscript: """
            Reminder — the dry cleaning ticket is in my jacket pocket, pickup \
            by Friday or they hold it another week.
            """,
            polishedSummary: """
            Dry cleaning ticket is in the jacket pocket — pick up by Friday.
            """,
            tags: ["errand"]
        )

        let task = TaskItem(
            text: "Text Priya to set up coffee next week",
            status: .open,
            sourceMomentIDs: [momentA.id],
            createdAt: momentA.createdAt
        )

        moments.insert(momentA, at: 0)
        moments.insert(momentB, at: 1)
        tasks.insert(task, at: 0)
    }
}

/// A day's worth of open tasks — the unit the See-all Tasks view renders
/// under a "Today" / "Yesterday" / dated header.
public struct TaskDayGroup: Identifiable {
    public let day: Date
    public let tasks: [TaskItem]
    public var id: Date { day }
}
