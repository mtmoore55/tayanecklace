import Foundation

public struct ChatMessage: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let role: Role
    public let text: String
    public let createdAt: Date

    public enum Role: String, Hashable, Sendable {
        case user, taya
    }

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

public struct Chat: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var messages: [ChatMessage]

    public init(id: UUID = UUID(), title: String, messages: [ChatMessage]) {
        self.id = id
        self.title = title
        self.messages = messages
    }

    /// Most recent message timestamp. Used for the chat-list sort + label.
    public var lastMessageAt: Date {
        messages.last?.createdAt ?? .distantPast
    }

    /// One-line preview of the last message (typically the Taya response).
    public var preview: String {
        messages.last?.text ?? ""
    }
}
