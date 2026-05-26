import Foundation
import Observation

@Observable
@MainActor
public final class DataStore {
    public var moments: [Moment]
    public var tasks: [TaskItem]
    public var people: [Person]
    public var chats: [Chat]

    public init(
        moments: [Moment] = [],
        tasks: [TaskItem] = [],
        people: [Person] = [],
        chats: [Chat] = []
    ) {
        self.moments = moments
        self.tasks = tasks
        self.people = people
        self.chats = chats
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
        tasks.filter { $0.sourceMomentID == momentID }
    }

    public func people(in momentID: UUID) -> [Person] {
        people.filter { $0.mentionedInMomentIDs.contains(momentID) }
    }

    // MARK: - Provenance (entity ⟶ moments)

    public func moments(mentioning personID: UUID) -> [Moment] {
        guard let person = person(personID) else { return [] }
        let ids = Set(person.mentionedInMomentIDs)
        return moments
            .filter { ids.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func sourceMoment(of task: TaskItem) -> Moment? {
        moment(task.sourceMomentID)
    }

    // MARK: - Curated views (for Home)

    /// Open tasks, oldest first — so anything carried over from prior days surfaces first.
    public func openTasks() -> [TaskItem] {
        tasks
            .filter { $0.status == .open }
            .sorted { lhs, rhs in
                let l = sourceMoment(of: lhs)?.createdAt ?? .distantPast
                let r = sourceMoment(of: rhs)?.createdAt ?? .distantPast
                return l < r
            }
    }

    /// Recent raw voice captures. Notes and journals have their own Home
    /// sections — Moments are the bedrock unstructured stream those derive
    /// from.
    public func recentMoments(limit: Int = 5) -> [Moment] {
        moments
            .filter { $0.kind == .voice }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    /// Recent short typed notes, newest first.
    public func recentNotes(limit: Int = 5) -> [Moment] {
        moments
            .filter { $0.kind == .note }
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
            !Set(person.mentionedInMomentIDs).isDisjoint(with: momentIDs)
        }
    }

    /// Chats sorted with the most recent first — what the Chats list view
    /// renders.
    public var chatsSortedByRecency: [Chat] {
        chats.sorted { $0.lastMessageAt > $1.lastMessageAt }
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
            if !people[idx].mentionedInMomentIDs.contains(moment.id) {
                people[idx].mentionedInMomentIDs.append(moment.id)
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
            sourceMomentID: momentA.id
        )

        moments.insert(momentA, at: 0)
        moments.insert(momentB, at: 1)
        tasks.insert(task, at: 0)
    }
}
