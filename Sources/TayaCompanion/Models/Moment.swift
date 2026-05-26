import Foundation

public enum MomentSource: String, Codable, Hashable, Sendable {
    case necklace
    case phone
}

public enum MomentKind: String, Codable, Hashable, Sendable {
    /// Audio-captured moment (necklace or phone). The default and most common kind.
    case voice
    /// Short user-typed capture — utility, glanceable.
    case note
    /// Long-form reflective entry — narrative prose.
    case journal
}

public struct Moment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let source: MomentSource
    public let kind: MomentKind
    public var title: String
    public var rawTranscript: String
    public var polishedSummary: String
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        source: MomentSource,
        kind: MomentKind = .voice,
        title: String,
        rawTranscript: String,
        polishedSummary: String,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.kind = kind
        self.title = title
        self.rawTranscript = rawTranscript
        self.polishedSummary = polishedSummary
        self.tags = tags
    }
}
