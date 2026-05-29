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

/// Layer 1 — one capture, distilled but never interpreted into action.
/// Immutable by construction: once distilled, a Moment is the tape and is
/// never edited. Everything actionable is projected *out* of it into `Entity`s.
public struct Moment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let source: MomentSource
    public let kind: MomentKind
    public let title: String
    public let rawTranscript: String
    public let polishedSummary: String
    public let tags: [String]
    /// Explicit location for this capture, when known (e.g. a place the
    /// necklace geotagged or the user attached). Distinct from places
    /// merely *mentioned* in the transcript, which are text-matched.
    public let place: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        source: MomentSource,
        kind: MomentKind = .voice,
        title: String,
        rawTranscript: String,
        polishedSummary: String,
        tags: [String] = [],
        place: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.kind = kind
        self.title = title
        self.rawTranscript = rawTranscript
        self.polishedSummary = polishedSummary
        self.tags = tags
        self.place = place
    }
}
