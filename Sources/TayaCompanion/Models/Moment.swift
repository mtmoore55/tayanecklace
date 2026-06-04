import Foundation

public enum MomentSource: String, Codable, Hashable, Sendable {
    case necklace
    case phone
}

/// Where a moment sits in the sync pipeline. `.synced` is the rest state;
/// `.pending` marks captures that were committed locally while offline and
/// will be flushed when connectivity returns. Surfaces as a small "Pending"
/// badge on moment rows.
public enum MomentSyncStatus: String, Codable, Hashable, Sendable {
    case synced
    case pending
}

/// Layer 1 — one capture, distilled but never interpreted into action.
/// Append-only: once distilled, the record's *fields* never change, and
/// everything actionable is projected *out* of it into `Entity`s. The
/// record itself can be voided via `deletedAt` when a user removes a
/// bad/mis-recorded moment — projections re-settle off the filtered set
/// while the record stays in the event log (restorable within the
/// 30-day retention window; see `DataStore.permanentlyDeleteMoment`).
public struct Moment: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let source: MomentSource
    public let title: String
    public let rawTranscript: String
    public let polishedSummary: String
    public let tags: [String]
    /// Explicit location for this capture, when known (e.g. a place the
    /// necklace geotagged or the user attached). Distinct from places
    /// merely *mentioned* in the transcript, which are text-matched.
    public let place: String?
    /// Sync pipeline state. Mutable so `DataStore.flushPendingMoments` can
    /// flip pending captures to synced when connectivity recovers.
    public var syncStatus: MomentSyncStatus
    /// Soft-delete timestamp. Non-nil hides the moment from every
    /// projection (recaps, mentions, themes, places, etc.) without
    /// removing it from the event log. Reversed by
    /// `DataStore.restoreMoment`; purged after 30 days by
    /// `purgeExpiredDeletedMoments`.
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        source: MomentSource,
        title: String,
        rawTranscript: String,
        polishedSummary: String,
        tags: [String] = [],
        place: String? = nil,
        syncStatus: MomentSyncStatus = .synced,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.title = title
        self.rawTranscript = rawTranscript
        self.polishedSummary = polishedSummary
        self.tags = tags
        self.place = place
        self.syncStatus = syncStatus
        self.deletedAt = deletedAt
    }
}
