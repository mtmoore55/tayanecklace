import Foundation

public enum MomentSource: String, Codable, Hashable, Sendable {
    case necklace
    case phone
}

public struct Moment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let source: MomentSource
    public var title: String
    public var rawTranscript: String
    public var polishedSummary: String
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        source: MomentSource,
        title: String,
        rawTranscript: String,
        polishedSummary: String,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.title = title
        self.rawTranscript = rawTranscript
        self.polishedSummary = polishedSummary
        self.tags = tags
    }
}
