import Foundation

/// Serializes Moments to Markdown for the native share sheet — structured so
/// it lands richly in Notes / Notion / Obsidian (headings, task checkboxes,
/// people, tags) rather than as a flat blob. The single source of truth for
/// what an exported moment looks like, shared by the per-moment share and the
/// filtered bulk export.
@MainActor
enum MomentExport {
    /// One moment, led by an `##` title. Used by the per-moment share.
    static func markdown(for moment: Moment, store: DataStore) -> String {
        block(moment, store: store, heading: "##")
    }

    /// A collection, grouped by day under `##` date headings beneath a top
    /// `#` title. Used by the filtered list export.
    static func markdown(for moments: [Moment], store: DataStore, now: Date = Date()) -> String {
        guard !moments.isEmpty else { return "" }
        let cal = Calendar.current
        var out: [String] = ["# Taya Moments", "*Exported \(timestamp(now))*"]
        let buckets = Dictionary(grouping: moments) { cal.startOfDay(for: $0.createdAt) }
        for day in buckets.keys.sorted(by: >) {
            out.append("")
            out.append("## \(RelativeDay.sectionLabel(from: day, now: now))")
            for moment in buckets[day]!.sorted(by: { $0.createdAt > $1.createdAt }) {
                out.append("")
                out.append(block(moment, store: store, heading: "###"))
            }
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Building blocks

    private static func block(_ moment: Moment, store: DataStore, heading: String) -> String {
        var lines: [String] = []
        lines.append("\(heading) \(moment.title)")
        lines.append("*\(sourceLabel(moment.source)) · \(timestamp(moment.createdAt))*")

        if !moment.polishedSummary.isEmpty {
            lines.append("")
            lines.append(moment.polishedSummary)
        }

        // Only include the transcript when it adds something beyond the summary
        // (typed notes reuse the same text for both).
        if !moment.rawTranscript.isEmpty, moment.rawTranscript != moment.polishedSummary {
            lines.append("")
            lines.append("**Transcript**")
            lines.append(moment.rawTranscript)
        }

        let tasks = store.tasks(from: moment.id)
        if !tasks.isEmpty {
            lines.append("")
            lines.append("**Tasks**")
            for task in tasks {
                lines.append("- [\(task.status == .done ? "x" : " ")] \(task.text)")
            }
        }

        let people = store.people(in: moment.id)
        if !people.isEmpty {
            lines.append("")
            lines.append("**People:** " + people.map(\.name).joined(separator: ", "))
        }

        if !moment.tags.isEmpty {
            lines.append("")
            lines.append(moment.tags.map { "#" + $0.replacingOccurrences(of: " ", with: "-") }.joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }

    private static func sourceLabel(_ source: MomentSource) -> String {
        switch source {
        case .necklace: return "Necklace"
        case .phone:    return "Phone"
        }
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
