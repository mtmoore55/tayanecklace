import Foundation

/// What Taya's reply (or a user message) is actually carrying. User
/// messages are always `.text`; Taya replies can be `.text` for narration
/// or one of the list cases when the natural answer is a set of entities
/// (tasks, places, people, moments). List cases store IDs, not snapshots,
/// so rows stay live as the underlying DataStore mutates.
public enum ChatContent: Hashable, Sendable {
    case text(String)
    case tasks(intro: String?, ids: [UUID])
    case places(intro: String?, names: [String])
    case people(intro: String?, ids: [UUID])
    case moments(intro: String?, ids: [UUID])

    /// Plain-text fallback. Drives chat-history previews, copy/share, and
    /// the toast surface — anything that needs a one-line representation
    /// of a structured reply.
    public var previewText: String {
        switch self {
        case .text(let s):
            return s
        case .tasks(let intro, let ids):
            return intro ?? defaultPreview(count: ids.count, singular: "task", plural: "tasks")
        case .places(let intro, let names):
            return intro ?? defaultPreview(count: names.count, singular: "place", plural: "places")
        case .people(let intro, let ids):
            return intro ?? defaultPreview(count: ids.count, singular: "person", plural: "people")
        case .moments(let intro, let ids):
            return intro ?? defaultPreview(count: ids.count, singular: "moment", plural: "moments")
        }
    }

    private func defaultPreview(count: Int, singular: String, plural: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }
}

public struct ChatMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let role: Role
    public let content: ChatContent
    public let createdAt: Date

    public enum Role: String, Hashable, Sendable {
        case user, taya
    }

    public init(
        id: UUID = UUID(),
        role: Role,
        content: ChatContent,
        createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    /// Convenience for the common text-only case (every user-typed
    /// message, plus Taya's fallback narration). Wraps the string in
    /// `.text(_)` so callers don't have to know about `ChatContent`.
    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date
    ) {
        self.init(id: id, role: role, content: .text(text), createdAt: createdAt)
    }

    /// Plain-text view of the message. Identical to `content.previewText`
    /// — preserved so copy/share/toast call-sites keep compiling.
    public var text: String { content.previewText }
}

public struct Chat: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var messages: [ChatMessage]
    /// Soft-delete timestamp. Non-nil hides the chat from every list
    /// surface (Home snack, ChatsTimelineSheet). Reversed by
    /// `DataStore.restoreChat`; purged after 30 days by
    /// `purgeExpiredDeletedChats`.
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        messages: [ChatMessage],
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.deletedAt = deletedAt
    }

    /// Most recent message timestamp. Used for the chat-list sort + label.
    public var lastMessageAt: Date {
        messages.last?.createdAt ?? .distantPast
    }

    /// One-line preview of the last message (typically the Taya response).
    public var preview: String {
        messages.last?.content.previewText ?? ""
    }
}
