import SwiftUI

/// Identifiable wrapper so a moment can drive `.sheet(item:)` presentation
/// across the app without forcing every caller to wrap UUIDs manually.
struct MomentRoute: Identifiable, Hashable {
    let id: Moment.ID
}

/// Minimal moment detail — title, polished summary, source/time, and the
/// entities extracted from this moment. Presented as a bottom sheet. The
/// Summary/Transcript segmented picker and the Copy/Share bar land in step 4.
///
/// Looks up the Moment by ID from the live DataStore so edits in the store
/// are reflected here.
struct MomentDetailView: View {
    let momentID: Moment.ID
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let moment = store.moment(momentID) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header(for: moment)
                            summaryCard(for: moment)
                            entityChips(for: moment)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .background(Theme.background)
                    .scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView("Moment not found", systemImage: "questionmark.folder")
                }
            }
            .navigationTitle("Moment")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func header(for moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(moment.title)
                .font(.system(.title2, design: .default, weight: .semibold))
            HStack(spacing: 6) {
                Image(systemName: moment.source == .necklace ? "circle.dotted.circle" : "iphone")
                    .font(.system(size: 12, weight: .regular))
                Text(sourceLabel(moment.source))
                Text("·")
                Text(moment.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(Theme.caption())
            .foregroundStyle(Theme.secondaryText)
        }
    }

    private func summaryCard(for moment: Moment) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(.uppercase)
                Text(moment.polishedSummary)
                    .font(Theme.body())
                    .foregroundStyle(Theme.primaryText)
            }
        }
    }

    @ViewBuilder
    private func entityChips(for moment: Moment) -> some View {
        let extractedTasks = store.tasks(from: moment.id)
        let extractedPeople = store.people(in: moment.id)
        if !extractedTasks.isEmpty || !extractedPeople.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Extracted")
                    .font(Theme.caption())
                    .foregroundStyle(Theme.secondaryText)
                    .textCase(.uppercase)
                FlowChips(
                    items: extractedPeople.map { .person($0) }
                          + extractedTasks.map { .task($0) }
                )
            }
        }
    }

    private func sourceLabel(_ source: MomentSource) -> String {
        switch source {
        case .necklace: return "Necklace"
        case .phone: return "Phone"
        }
    }
}

private enum ExtractedChip: Identifiable {
    case person(Person)
    case task(TaskItem)

    var id: String {
        switch self {
        case .person(let p): return "person-\(p.id)"
        case .task(let t):   return "task-\(t.id)"
        }
    }

    var label: String {
        switch self {
        case .person(let p): return p.name
        case .task(let t):   return t.text
        }
    }

    var systemImage: String {
        switch self {
        case .person:        return "person.circle"
        case .task:          return "checklist"
        }
    }
}

private struct FlowChips: View {
    let items: [ExtractedChip]

    var body: some View {
        // Simple wrapping flow using a LazyVGrid with adaptive columns.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 120), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(items) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 12, weight: .regular))
                    Text(item.label)
                        .font(Theme.caption())
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous).fill(Theme.accentSoft)
                )
                .foregroundStyle(Theme.accent)
            }
        }
    }
}
