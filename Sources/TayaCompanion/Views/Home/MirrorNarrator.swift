import Foundation

/// Composes the Mirror's lead paragraph for each lens from the live entities —
/// specific names, dates, what's still open, the resurfaced moment's own
/// summary — so the line reads like Taya noticed something rather than a
/// generic label.
///
/// This is the deterministic stand-in for the eventual LLM reflection: the
/// real product would generate this from the Moment log. Keeping it behind one
/// `lead(for:store:)` entry point means that swap is a single call site.
@MainActor
enum MirrorNarrator {
    static func lead(for lens: MirrorLens, store: DataStore, now: Date = Date()) -> String {
        switch lens {
        case .reflection: return reflection(store, now: now)
        case .focus:      return focus(store, now: now)
        case .revisit:    return revisit(store, now: now)
        case .people:     return people(store, now: now)
        case .themes:     return themes(store, now: now)
        // The "For you" lens renders seeded suggestions with their own leads,
        // so it doesn't route through the narrator (handled in HomeView).
        case .forYou:     return "Here's what I've been working on for you."
        }
    }

    // MARK: - Reflection

    private static func reflection(_ store: DataStore, now: Date) -> String {
        var sentences: [String] = []

        let ranked = rankedPeople(store)
        if !ranked.isEmpty {
            let names = naturalList(ranked.prefix(3).map(\.name))
            sentences.append("The last few days kept circling back to \(names).")
        } else {
            sentences.append("It's been a quieter stretch — mostly your own thoughts.")
        }

        if let top = topThemes(store, limit: 2), top.count >= 2 {
            sentences.append("\(capitalizedFirst(top[0])) and \(top[1]) ran through most of what you captured.")
        } else if let top = topThemes(store, limit: 1), let t = top.first {
            sentences.append("\(capitalizedFirst(t)) ran through most of what you captured.")
        }

        let open = store.openTasks()
        if open.isEmpty {
            sentences.append("Nothing's hanging over you right now — you're clear.")
        } else {
            let n = open.count
            var s = "\(n) \(n == 1 ? "thing you flagged is" : "things you flagged are") still open"
            if let oldest = open.first, let day = sourceDay(of: oldest, store: store, now: now) {
                s += ", the oldest waiting since \(day)"
            }
            sentences.append(s + ".")
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Focus

    private static func focus(_ store: DataStore, now: Date) -> String {
        let open = store.openTasks()
        guard !open.isEmpty else {
            return "You're all caught up — nothing open right now. A good moment to capture something new before it slips."
        }

        var sentences: [String] = []
        let n = open.count
        let carried = carriedCount(open, store: store, now: now)
        var lead = "\(n) \(n == 1 ? "thread is" : "threads are") still open"
        if carried > 0 {
            lead += " — \(carried) carried over from earlier in the week"
        }
        sentences.append(lead + ".")

        if let due = soonestDue(open) {
            sentences.append("\"\(due.text)\" is the one with a clock on it — \(dueClause(due.dueAt)) — so start there.")
        } else if let oldest = open.first, let day = sourceDay(of: oldest, store: store, now: now) {
            sentences.append("\"\(oldest.text)\" has been waiting since \(day) — starting there lifts the most weight.")
        }

        sentences.append("The rest can follow once it's off your plate.")
        return sentences.joined(separator: " ")
    }

    // MARK: - Revisit

    private static func revisit(_ store: DataStore, now: Date) -> String {
        let moment = store.resurfaced().first ?? store.recentMoments(limit: 1).first
        guard let m = moment else {
            return "Nothing's resurfaced yet — once you've captured more, older threads worth a second look will gather here."
        }
        var s = "\(whenPhrase(m.createdAt, now: now)) you captured \"\(m.title).\" "
        s += m.polishedSummary
        if !m.polishedSummary.hasSuffix(".") { s += "." }
        s += " It's been sitting a few days without a follow-up — worth a second look before it fades."
        return s
    }

    // MARK: - People

    private static func people(_ store: DataStore, now: Date) -> String {
        let ranked = rankedPeople(store)
        guard let top = ranked.first else {
            return "No one's come up much yet — as you capture more conversations, the people who matter will gather here."
        }

        var sentences: [String] = []
        let count = top.sourceMomentIDs.count
        sentences.append("\(top.name) keeps coming up — \(count) \(count == 1 ? "mention" : "mentions") lately.")

        if let task = openTask(involving: top, store: store) {
            sentences.append("There's still \"\(task.text)\" waiting on your side.")
        } else if let fact = top.facts.first {
            sentences.append(fact.hasSuffix(".") ? fact : fact + ".")
        }

        if ranked.count > 1 {
            let others = naturalList(ranked.dropFirst().prefix(2).map(\.name))
            let verb = (ranked.count == 2) ? "has" : "have"
            sentences.append("\(others) \(verb) been on your mind too — a quick check-in would close an open loop.")
        }

        return sentences.joined(separator: " ")
    }

    // MARK: - Themes

    private static func themes(_ store: DataStore, now: Date) -> String {
        guard let top = topThemes(store, limit: 3), !top.isEmpty else {
            return "No clear themes yet — patterns will surface as you capture more."
        }
        var s: String
        if top.count >= 2 {
            s = "\(capitalizedFirst(top[0])) and \(top[1]) keep surfacing across what you capture."
        } else {
            s = "\(capitalizedFirst(top[0])) keeps surfacing across what you capture."
        }
        if top.count >= 3 {
            s += " \(capitalizedFirst(top[2])) runs underneath it too."
        }
        s += " It's a sketch of where your attention's been going lately — worth noticing what you keep returning to."
        return s
    }

    // MARK: - Data helpers

    private static func rankedPeople(_ store: DataStore) -> [Person] {
        store.people.sorted { $0.sourceMomentIDs.count > $1.sourceMomentIDs.count }
    }

    /// Tags sorted by how many moments carry them, most frequent first.
    /// Ties broken alphabetically for stable copy. Returns nil when empty.
    private static func topThemes(_ store: DataStore, limit: Int) -> [String]? {
        var counts: [String: Int] = [:]
        for moment in store.activeMoments {
            for tag in moment.tags { counts[tag, default: 0] += 1 }
        }
        let sorted = counts.sorted {
            $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key
        }
        let result = Array(sorted.prefix(limit).map(\.key))
        return result.isEmpty ? nil : result
    }

    private static func openTask(involving person: Person, store: DataStore) -> TaskItem? {
        let ids = Set(person.sourceMomentIDs)
        return store.openTasks().first { !Set($0.sourceMomentIDs).isDisjoint(with: ids) }
    }

    private static func soonestDue(_ tasks: [TaskItem]) -> TaskItem? {
        tasks
            .compactMap { task in task.dueAt.map { (task, $0) } }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func carriedCount(_ tasks: [TaskItem], store: DataStore, now: Date) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        return tasks.filter { task in
            guard let moment = store.sourceMoment(of: task) else { return false }
            return cal.startOfDay(for: moment.createdAt) < today
        }.count
    }

    // MARK: - Date / string helpers

    private static func sourceDay(of task: TaskItem, store: DataStore, now: Date) -> String? {
        guard let moment = store.sourceMoment(of: task) else { return nil }
        return dayName(moment.createdAt, now: now)
    }

    /// "today" / "yesterday" / "Monday" / "May 24" — for mid-sentence use
    /// ("waiting since Monday").
    private static func dayName(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<0, 0: return "today"
        case 1:       return "yesterday"
        case 2...6:   return formatted(date, "EEEE")
        default:      return formatted(date, "MMM d")
        }
    }

    /// Sentence-leading form: "Earlier today" / "Yesterday" / "Back on Monday".
    private static func whenPhrase(_ date: Date, now: Date) -> String {
        switch dayName(date, now: now) {
        case "today":     return "Earlier today"
        case "yesterday": return "Yesterday"
        case let other:   return "Back on \(other)"
        }
    }

    private static func dueClause(_ date: Date?) -> String {
        guard let date else { return "with a deadline" }
        return "due \(formatted(date, "MMM d"))"
    }

    private static func formatted(_ date: Date, _ format: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = format
        return fmt.string(from: date)
    }

    private static func naturalList(_ items: some Collection<String>) -> String {
        let list = Array(items)
        switch list.count {
        case 0:  return ""
        case 1:  return list[0]
        case 2:  return "\(list[0]) and \(list[1])"
        default: return list.dropLast().joined(separator: ", ") + ", and " + list.last!
        }
    }

    private static func capitalizedFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
