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
        tasks.filter { $0.deletedAt == nil && $0.sourceMomentIDs.contains(momentID) }
    }

    public func people(in momentID: UUID) -> [Person] {
        people.filter { $0.sourceMomentIDs.contains(momentID) }
    }

    // MARK: - Provenance (entity ⟶ moments)

    public func moments(mentioning personID: UUID) -> [Moment] {
        guard let person = person(personID) else { return [] }
        let ids = Set(person.sourceMomentIDs)
        return moments
            .filter { $0.deletedAt == nil && ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func sourceMoment(of task: TaskItem) -> Moment? {
        guard let originID = task.originMomentID,
              let m = moment(originID),
              m.deletedAt == nil
        else { return nil }
        return m
    }

    // MARK: - Curated views (for Home)

    /// Open tasks, oldest first — so anything carried over from prior days surfaces first.
    public func openTasks() -> [TaskItem] {
        tasks
            .filter { $0.status == .open && $0.deletedAt == nil }
            .sorted { lhs, rhs in effectiveDate(lhs) < effectiveDate(rhs) }
    }

    /// Tasks completed today, most-recently-completed first. Home keeps
    /// these visible (sunk below the open ones) so checking something off
    /// is satisfying rather than making it vanish.
    public func tasksCompletedToday(now: Date = Date()) -> [TaskItem] {
        let cal = Calendar.current
        return tasks
            .filter {
                $0.status == .done
                && $0.deletedAt == nil
                && cal.isDate($0.updatedAt, inSameDayAs: now)
            }
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
        let open = tasks.filter { $0.status == .open && $0.deletedAt == nil }
        return Dictionary(grouping: open) { cal.startOfDay(for: effectiveDate($0)) }
            .map { day, items in TaskDayGroup(day: day, tasks: items) }
            .sorted { $0.day > $1.day }
    }

    /// All completed tasks, most-recently-completed first — the See-all
    /// "Completed" section.
    public func completedTasks() -> [TaskItem] {
        tasks
            .filter { $0.status == .done && $0.deletedAt == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Completed tasks grouped by the day they were completed
    /// (`updatedAt`). Drives the History sheet — newest day first,
    /// rows within a day also newest-first.
    public func completedTasksGroupedByDay() -> [TaskDayGroup] {
        let cal = Calendar.current
        let done = tasks.filter { $0.status == .done && $0.deletedAt == nil }
        return Dictionary(grouping: done) { cal.startOfDay(for: $0.updatedAt) }
            .map { day, items in
                TaskDayGroup(day: day, tasks: items.sorted { $0.updatedAt > $1.updatedAt })
            }
            .sorted { $0.day > $1.day }
    }

    /// Soft-deleted tasks grouped by the day the user deleted them,
    /// newest-deletion first. Drives the Recently Deleted sheet.
    public func recentlyDeletedTasksGroupedByDay() -> [TaskDayGroup] {
        let cal = Calendar.current
        let deleted = tasks.compactMap { task -> (Date, TaskItem)? in
            guard let when = task.deletedAt else { return nil }
            return (when, task)
        }
        return Dictionary(grouping: deleted) { cal.startOfDay(for: $0.0) }
            .map { day, pairs in
                TaskDayGroup(
                    day: day,
                    tasks: pairs
                        .sorted { $0.0 > $1.0 }
                        .map { $0.1 }
                )
            }
            .sorted { $0.day > $1.day }
    }

    /// The day a task belongs to — its source moment's day when derived,
    /// else its own creation day.
    private func effectiveDate(_ task: TaskItem) -> Date {
        sourceMoment(of: task)?.createdAt ?? task.createdAt
    }

    /// Recent moments, newest first — Home's all-time Moments stream.
    public func recentMoments(limit: Int = 5) -> [Moment] {
        activeMoments
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Unique themes — set of all tags across all moments, deduped.
    public var themes: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for tag in activeMoments.flatMap({ $0.tags }) {
            if seen.insert(tag).inserted { out.append(tag) }
        }
        return out
    }

    /// Every non-deleted moment. The filter applied at the projection
    /// layer so soft-deleted moments stay in `moments` (the event log)
    /// but vanish from every surface that derives from them.
    public var activeMoments: [Moment] {
        moments.filter { $0.deletedAt == nil }
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
        activeMoments.filter { moment in
            moment.title.localizedCaseInsensitiveContains(place)
                || moment.polishedSummary.localizedCaseInsensitiveContains(place)
                || moment.rawTranscript.localizedCaseInsensitiveContains(place)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// Moments tagged with a theme (exact match on tag).
    public func moments(taggedWith theme: String) -> [Moment] {
        activeMoments
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
    /// renders. Soft-deleted chats are excluded; they surface only in the
    /// Recently Deleted Chats sheet.
    public var chatsSortedByRecency: [Chat] {
        chats
            .filter { $0.deletedAt == nil }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    /// Recent chats for Home's Chats section, newest first.
    public func recentChats(limit: Int = 3) -> [Chat] {
        Array(chatsSortedByRecency.prefix(limit))
    }

    public func chat(_ id: Chat.ID) -> Chat? {
        chats.first { $0.id == id }
    }

    /// Chats whose most recent message lands on the given day. Excludes
    /// soft-deleted chats so the day's recap doesn't list a vanished chat.
    public func chats(on day: Date) -> [Chat] {
        let cal = Calendar.current
        let target = cal.startOfDay(for: day)
        return chats
            .filter { $0.deletedAt == nil && cal.startOfDay(for: $0.lastMessageAt) == target }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    // MARK: - Daily Recap (derived projection)

    /// All primitives recorded on `day`, woven into a single value the UI
    /// can render in one pass. Computed per call — no caching, no storage.
    /// Mirror is forward-looking; Recap is backward-looking.
    public func recap(for day: Date) -> DayRecap {
        let cal = Calendar.current
        let bucket = cal.startOfDay(for: day)

        let dayMoments = activeMoments
            .filter { cal.startOfDay(for: $0.createdAt) == bucket }
            .sorted { $0.createdAt < $1.createdAt }
        let momentIDs = Set(dayMoments.map(\.id))

        // A task "happens on" the day of its source moment when derived,
        // else its own creation day — matches `effectiveDate` elsewhere.
        let tasksCreated = tasks.filter { task in
            guard task.deletedAt == nil else { return false }
            let happenedOn = cal.startOfDay(for: effectiveDate(task))
            return happenedOn == bucket
        }
        let tasksCompleted = tasks.filter { task in
            task.deletedAt == nil
                && task.status == .done
                && cal.startOfDay(for: task.updatedAt) == bucket
        }
        let dayChats = chats(on: bucket)

        let dayPeople = people.filter { person in
            !Set(person.sourceMomentIDs).isDisjoint(with: momentIDs)
        }

        let placeSet = Set(dayMoments.compactMap(\.place))
        let mentionedPlaces = places.filter { place in
            dayMoments.contains { moment in
                moment.title.localizedCaseInsensitiveContains(place)
                    || moment.polishedSummary.localizedCaseInsensitiveContains(place)
                    || moment.rawTranscript.localizedCaseInsensitiveContains(place)
            }
        }
        var seenPlace = Set<String>()
        let dayPlaces = (Array(placeSet) + mentionedPlaces).filter { seenPlace.insert($0).inserted }

        var seenTheme = Set<String>()
        let dayThemes = dayMoments.flatMap(\.tags).filter { seenTheme.insert($0).inserted }

        // Stub summary: stitched polished summaries until the LLM swap-in.
        let summary = dayMoments
            .map(\.polishedSummary)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return DayRecap(
            day: bucket,
            moments: dayMoments,
            tasksCreated: tasksCreated,
            tasksCompleted: tasksCompleted,
            people: dayPeople,
            places: dayPlaces,
            themes: dayThemes,
            chats: dayChats,
            summary: summary
        )
    }

    /// The dates the Home day-strip should render — `count` most recent
    /// days ending at `today`, oldest → newest. Activity is queried per
    /// day via `recap(for:).hasActivity` so the strip and content share a
    /// single source of truth.
    public func recapDays(through today: Date = Date(), count: Int = 14) -> [Date] {
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: today)
        return (0..<count)
            .compactMap { offset in
                cal.date(byAdding: .day, value: -offset, to: endDay)
            }
            .reversed()
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
        return activeMoments
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

    /// Soft delete — moves the task into Recently Deleted (where it
    /// lingers for `Self.recentlyDeletedRetention` before being purged
    /// by `purgeExpiredDeletedTasks`). Use `permanentlyDeleteTask` for
    /// the hard-remove path from Recently Deleted.
    public func deleteTask(_ task: TaskItem, now: Date = Date()) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].deletedAt = now
        tasks[idx].updatedAt = now
    }

    /// Pull a soft-deleted task back into the active world.
    public func restoreTask(_ task: TaskItem, now: Date = Date()) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].deletedAt = nil
        tasks[idx].updatedAt = now
    }

    /// Hard-remove a task — bypasses the Recently Deleted holding pen.
    /// Used by the "Delete permanently" row action and by the purge sweep.
    public func permanentlyDeleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
    }

    /// Soft-delete every completed task — the "Clear completed"
    /// affordance in the Tasks/History ellipsis menus. Items still land
    /// in Recently Deleted so the action is recoverable.
    public func clearCompletedTasks(now: Date = Date()) {
        for idx in tasks.indices where tasks[idx].status == .done && tasks[idx].deletedAt == nil {
            tasks[idx].deletedAt = now
            tasks[idx].updatedAt = now
        }
    }

    /// How long a soft-deleted task survives in Recently Deleted before
    /// the purge sweep removes it for real. Shared by every soft-delete
    /// pipeline (tasks, moments, chats) so they age out together.
    public static let recentlyDeletedRetention: TimeInterval = 30 * 24 * 60 * 60

    /// Remove tasks whose `deletedAt` is older than the retention window.
    /// Called on view appear in the Tasks surfaces so the holding pen
    /// stays bounded without a background job.
    public func purgeExpiredDeletedTasks(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.recentlyDeletedRetention)
        tasks.removeAll { task in
            guard let when = task.deletedAt else { return false }
            return when < cutoff
        }
    }

    // MARK: - Moments soft-delete

    /// Soft-delete a moment. The record stays in the event log; projections
    /// (recaps, themes, places, person mentions, source links) re-settle
    /// off `activeMoments`. Recoverable within the 30-day retention window
    /// via `restoreMoment`.
    public func deleteMoment(_ moment: Moment, now: Date = Date()) {
        guard let idx = moments.firstIndex(where: { $0.id == moment.id }) else { return }
        moments[idx].deletedAt = now
    }

    /// Bring a soft-deleted moment back; projections re-include it.
    public func restoreMoment(_ moment: Moment, now: Date = Date()) {
        guard let idx = moments.firstIndex(where: { $0.id == moment.id }) else { return }
        moments[idx].deletedAt = nil
    }

    /// Hard-remove a moment from the event log. After this, any task or
    /// person fact whose `sourceMomentIDs` referenced it dangles.
    public func permanentlyDeleteMoment(_ moment: Moment) {
        moments.removeAll { $0.id == moment.id }
    }

    /// Sweep soft-deleted moments past the retention window. Same 30-day
    /// cliff as tasks.
    public func purgeExpiredDeletedMoments(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.recentlyDeletedRetention)
        moments.removeAll { moment in
            guard let when = moment.deletedAt else { return false }
            return when < cutoff
        }
    }

    /// Soft-deleted moments grouped by the day the user deleted them,
    /// newest-deletion first. Drives the Recently Deleted Moments sheet.
    public func recentlyDeletedMomentsGroupedByDay() -> [MomentDayGroup] {
        let cal = Calendar.current
        let deleted = moments.compactMap { moment -> (Date, Moment)? in
            guard let when = moment.deletedAt else { return nil }
            return (when, moment)
        }
        return Dictionary(grouping: deleted) { cal.startOfDay(for: $0.0) }
            .map { day, pairs in
                MomentDayGroup(
                    day: day,
                    moments: pairs
                        .sorted { $0.0 > $1.0 }
                        .map { $0.1 }
                )
            }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Chats soft-delete

    /// Soft-delete a chat. The chat disappears from the Home snack and
    /// `ChatsTimelineSheet`; surfaces in Recently Deleted Chats until the
    /// 30-day retention window closes.
    public func deleteChat(_ chat: Chat, now: Date = Date()) {
        guard let idx = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[idx].deletedAt = now
    }

    public func restoreChat(_ chat: Chat, now: Date = Date()) {
        guard let idx = chats.firstIndex(where: { $0.id == chat.id }) else { return }
        chats[idx].deletedAt = nil
    }

    public func permanentlyDeleteChat(_ chat: Chat) {
        chats.removeAll { $0.id == chat.id }
    }

    public func purgeExpiredDeletedChats(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-Self.recentlyDeletedRetention)
        chats.removeAll { chat in
            guard let when = chat.deletedAt else { return false }
            return when < cutoff
        }
    }

    /// Soft-deleted chats grouped by the day the user deleted them,
    /// newest-deletion first. Drives the Recently Deleted Chats sheet.
    public func recentlyDeletedChatsGroupedByDay() -> [ChatDayGroup] {
        let cal = Calendar.current
        let deleted = chats.compactMap { chat -> (Date, Chat)? in
            guard let when = chat.deletedAt else { return nil }
            return (when, chat)
        }
        return Dictionary(grouping: deleted) { cal.startOfDay(for: $0.0) }
            .map { day, pairs in
                ChatDayGroup(
                    day: day,
                    chats: pairs
                        .sorted { $0.0 > $1.0 }
                        .map { $0.1 }
                )
            }
            .sorted { $0.day > $1.day }
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

    /// Append a structured message to an existing chat. Used by chat
    /// detail views when the user continues a conversation or when Taya
    /// replies with a list of entities (tasks, places, etc.).
    public func appendMessage(to chatID: Chat.ID, role: ChatMessage.Role, content: ChatContent) {
        guard let idx = chats.firstIndex(where: { $0.id == chatID }) else { return }
        let message = ChatMessage(role: role, content: content, createdAt: Date())
        chats[idx].messages.append(message)
    }

    /// Text-only convenience for the common case (every user-typed
    /// message, plus Taya's fallback narration).
    public func appendMessage(to chatID: Chat.ID, role: ChatMessage.Role, text: String) {
        appendMessage(to: chatID, role: role, content: .text(text))
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

    /// A phone-side capture coming out of `CaptureSheet`. When connectivity
    /// is degraded we stamp it `.pending` so the moment row renders the
    /// pending badge and `flushPendingMoments` picks it up on recovery.
    /// Demo-grade copy stands in for what a real transcript pipeline lands.
    public func appendPhoneMoment(now: Date = Date(), syncStatus: MomentSyncStatus = .synced) {
        let moment = Moment(
            createdAt: now,
            source: .phone,
            title: "Voice capture",
            rawTranscript: "",
            polishedSummary: "A quick voice capture from your phone.",
            tags: [],
            syncStatus: syncStatus
        )
        moments.insert(moment, at: 0)
    }

    /// Flips every `.pending` moment to `.synced`. Called when connectivity
    /// returns to `.ok` — the demo's equivalent of the queue draining.
    public func flushPendingMoments() {
        for idx in moments.indices where moments[idx].syncStatus == .pending {
            moments[idx].syncStatus = .synced
        }
    }
}

/// A day's worth of open tasks — the unit the See-all Tasks view renders
/// under a "Today" / "Yesterday" / dated header.
public struct TaskDayGroup: Identifiable {
    public let day: Date
    public let tasks: [TaskItem]
    public var id: Date { day }
}

/// A day's worth of soft-deleted moments — the unit the Recently Deleted
/// Moments sheet renders under a "Today" / "Yesterday" / dated header.
public struct MomentDayGroup: Identifiable {
    public let day: Date
    public let moments: [Moment]
    public var id: Date { day }
}

/// A day's worth of soft-deleted chats.
public struct ChatDayGroup: Identifiable {
    public let day: Date
    public let chats: [Chat]
    public var id: Date { day }
}
