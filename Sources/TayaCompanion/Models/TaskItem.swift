import Foundation

public enum TaskStatus: String, Codable, Hashable, Sendable {
    case open
    case done
}

/// Layer 2 — an actionable item projected from one or more Moments.
/// Mostly create-and-complete, but a later Moment can revise its wording,
/// due date, or status via `merge`.
// Named `TaskItem` to avoid shadowing Swift's `_Concurrency.Task`.
public struct TaskItem: Entity, Hashable {
    public let id: UUID
    public var text: String
    public var status: TaskStatus
    public var dueAt: Date?
    /// Non-nil when the user has deleted the task. The row disappears
    /// from active/history views immediately but lingers in Recently
    /// Deleted for 30 days before being purged for real.
    public var deletedAt: Date?
    public var sourceMomentIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        status: TaskStatus = .open,
        dueAt: Date? = nil,
        deletedAt: Date? = nil,
        sourceMomentIDs: [UUID],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.status = status
        self.dueAt = dueAt
        self.deletedAt = deletedAt
        self.sourceMomentIDs = sourceMomentIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public mutating func mergeFields(from candidate: TaskItem) {
        text = candidate.text
        status = candidate.status
        if let due = candidate.dueAt { dueAt = due }
    }
}
