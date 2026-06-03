import Foundation

/// Derived projection of a single day's primitives — a backward-looking
/// companion to the Daily Mirror's forward-looking view. Composed on
/// demand from Moments + their extracted entities; never stored.
///
/// `summary` is a placeholder (concatenated polished summaries) until the
/// real LLM-generated prose lands. The seam is this one field.
public struct DayRecap: Hashable, Sendable {
    /// Bucket boundary — `Calendar.startOfDay(for:)` of any time on the day.
    public let day: Date
    public let moments: [Moment]
    public let tasksCreated: [TaskItem]
    public let tasksCompleted: [TaskItem]
    public let people: [Person]
    public let places: [String]
    public let themes: [String]
    public let chats: [Chat]
    public let summary: String

    public var hasActivity: Bool {
        !moments.isEmpty
            || !tasksCreated.isEmpty
            || !tasksCompleted.isEmpty
            || !chats.isEmpty
    }

    public init(
        day: Date,
        moments: [Moment] = [],
        tasksCreated: [TaskItem] = [],
        tasksCompleted: [TaskItem] = [],
        people: [Person] = [],
        places: [String] = [],
        themes: [String] = [],
        chats: [Chat] = [],
        summary: String = ""
    ) {
        self.day = day
        self.moments = moments
        self.tasksCreated = tasksCreated
        self.tasksCompleted = tasksCompleted
        self.people = people
        self.places = places
        self.themes = themes
        self.chats = chats
        self.summary = summary
    }
}
