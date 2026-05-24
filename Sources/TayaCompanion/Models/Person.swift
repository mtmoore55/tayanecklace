import Foundation

public struct Person: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var facts: [String]
    public var mentionedInMomentIDs: [UUID]

    public init(
        id: UUID = UUID(),
        name: String,
        facts: [String] = [],
        mentionedInMomentIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.facts = facts
        self.mentionedInMomentIDs = mentionedInMomentIDs
    }
}
