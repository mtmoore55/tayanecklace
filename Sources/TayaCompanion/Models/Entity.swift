import Foundation

/// The shared contract every Layer-2 projection satisfies (see `docs/data-model.md`).
///
/// An entity is *derived* from one or more Moments and must always be able to
/// cite them — that backlink (`sourceMomentIDs`) is what lets the UI answer
/// "why are you telling me this?". Entities are mutable: born from one Moment,
/// enriched by later ones through `merge(_:from:)`.
public protocol Entity: Identifiable, Sendable {
    var id: UUID { get }

    /// Provenance: every Moment that created *or* updated this entity. Ordered
    /// oldest-first, so `first` is the origin. Never empty for a resolved entity.
    var sourceMomentIDs: [UUID] { get set }

    /// Capture time of the first Moment that produced this entity.
    var createdAt: Date { get set }

    /// Capture time of the most recent Moment that touched this entity.
    var updatedAt: Date { get set }

    /// Fold the type-specific fields of a freshly-extracted candidate of the
    /// same type into this entity (union facts, prefer newer text, …).
    /// Provenance and `updatedAt` are handled by `merge(_:from:)` — implementors
    /// own only their own fields.
    mutating func mergeFields(from candidate: Self)
}

extension Entity {
    /// The UPDATE path from the Resolve & merge stage (data-model.md §5): fold
    /// `candidate` into this entity and record `moment` as new provenance.
    /// Idempotent on the Moment id, so re-running extraction can't duplicate a
    /// backlink.
    public mutating func merge(_ candidate: Self, from moment: Moment) {
        mergeFields(from: candidate)
        if !sourceMomentIDs.contains(moment.id) {
            sourceMomentIDs.append(moment.id)
        }
        updatedAt = Swift.max(updatedAt, moment.createdAt)
    }

    /// The Moment that created this entity, if any provenance is recorded.
    public var originMomentID: UUID? { sourceMomentIDs.first }
}
