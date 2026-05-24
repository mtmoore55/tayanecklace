import Foundation

public enum TaskStatus: String, Codable, Hashable, Sendable {
    case open
    case done
}

// Named `TaskItem` to avoid shadowing Swift's `_Concurrency.Task`.
public struct TaskItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var text: String
    public var status: TaskStatus
    public var dueAt: Date?
    public let sourceMomentID: UUID

    public init(
        id: UUID = UUID(),
        text: String,
        status: TaskStatus = .open,
        dueAt: Date? = nil,
        sourceMomentID: UUID
    ) {
        self.id = id
        self.text = text
        self.status = status
        self.dueAt = dueAt
        self.sourceMomentID = sourceMomentID
    }
}
