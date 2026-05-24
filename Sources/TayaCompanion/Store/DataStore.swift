import Foundation
import Observation

@Observable
@MainActor
public final class DataStore {
    public var moments: [Moment]
    public var tasks: [TaskItem]
    public var people: [Person]

    public init(
        moments: [Moment] = [],
        tasks: [TaskItem] = [],
        people: [Person] = []
    ) {
        self.moments = moments
        self.tasks = tasks
        self.people = people
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

    public func recentMoments(limit: Int = 5) -> [Moment] {
        moments
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Mutations (demo-grade)

    public func toggle(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].status = tasks[idx].status == .open ? .done : .open
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
}
