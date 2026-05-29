import Foundation

/// Layer 2 — a person who accumulates across Moments. The create-then-update
/// shape lives here: a new mention `merge`s its facts into the existing Person
/// and appends the Moment to provenance.
public struct Person: Entity, Hashable {
    public let id: UUID
    public var name: String
    public var facts: [String]
    public var sourceMomentIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        facts: [String] = [],
        sourceMomentIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.facts = facts
        self.sourceMomentIDs = sourceMomentIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    public mutating func mergeFields(from candidate: Person) {
        for fact in candidate.facts where !facts.contains(fact) {
            facts.append(fact)
        }
    }
}
