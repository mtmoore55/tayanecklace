import Foundation

/// A proactive proposal Taya generates by spotting an intent in a Moment and
/// doing work against it — finding options, checking availability. It's the
/// first *action-bearing* entity: Moments hold no actions and the other
/// entities reflect; a Suggestion proposes. It cites the Moment that triggered
/// it and carries options the user can act on — or dismiss.
///
/// Demo-grade: options are seeded. The real version is produced by the agent
/// pipeline (intent detection → search/integration → proposal).
public struct Suggestion: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Taya's conversational lead, in her voice.
    public let lead: String
    /// Provenance — the capture that triggered this, when known.
    public let sourceMomentID: UUID?
    public var options: [SuggestionOption]

    public init(
        id: UUID = UUID(),
        lead: String,
        sourceMomentID: UUID? = nil,
        options: [SuggestionOption]
    ) {
        self.id = id
        self.lead = lead
        self.sourceMomentID = sourceMomentID
        self.options = options
    }
}

public struct SuggestionOption: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String
    /// Third descriptor line — availability for places, a price/effort note
    /// for ideas.
    public let detail: String
    public let systemImage: String
    /// Where tapping the option goes — a reservation page, a product listing,
    /// etc. `nil` for options with nowhere to send the user yet.
    public let url: URL?

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        detail: String,
        systemImage: String,
        url: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.systemImage = systemImage
        self.url = url
    }
}
