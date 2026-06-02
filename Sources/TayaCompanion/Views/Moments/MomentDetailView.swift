import SwiftUI

/// Identifiable wrapper so a moment can drive `.sheet(item:)` presentation
/// across the app without forcing every caller to wrap UUIDs manually.
struct MomentRoute: Identifiable, Hashable {
    let id: Moment.ID
}

/// Minimal moment detail — title, full text, source/time, and the
/// entities extracted from this moment. Presented as a bottom sheet.
/// The shared `MomentActionsRow` (Chat / Copy / Share) sits below the
/// content as the closing action shelf.
///
/// Looks up the Moment by ID from the live DataStore so edits in the store
/// are reflected here.
struct MomentDetailView: View {
    let momentID: Moment.ID
    @Environment(DataStore.self) private var store

    @State private var askTayaQuery: String?

    var body: some View {
        Group {
            if let moment = store.moment(momentID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleRow(for: moment)
                        header(for: moment)
                        fullText(for: moment)
                        entityChips(for: moment)
                        actionsRow(for: moment)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .background(Theme.backgroundGradient.ignoresSafeArea())
                .scrollContentBackground(.hidden)
            } else {
                ContentUnavailableView("Moment not found", systemImage: "questionmark.folder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.backgroundGradient.ignoresSafeArea())
            }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .sheet(item: Binding(
            get: { askTayaQuery.map { MomentAskSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private func titleRow(for moment: Moment) -> some View {
        Text(moment.title)
            .font(Theme.titleM())
            .foregroundStyle(Theme.primaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func actionsRow(for moment: Moment) -> some View {
        MomentActionsRow(
            onChat: { askTayaQuery = "Tell me more about \"\(moment.title)\"" },
            copyText: moment.rawTranscript,
            shareItem: MomentExport.markdown(for: moment, store: store)
        )
        .padding(.top, 8)
    }

    private func header(for moment: Moment) -> some View {
        HStack(spacing: 6) {
            Image(systemName: moment.source == .necklace ? "circle.dotted.circle" : "iphone")
                .font(.system(size: 12, weight: .regular))
            Text(sourceLabel(moment.source))
            Text("·")
            Text(moment.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(Theme.caption())
        .foregroundStyle(Theme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fullText(for moment: Moment) -> some View {
        Text(moment.rawTranscript)
            .font(Theme.bodyL())
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Extracted entities grouped by category — location, then theme,
    /// then people, then the actions pulled out of them. Each category is
    /// its own labeled row so the strip reads as a structured table rather
    /// than a scattered chip cloud. Empty categories are omitted.
    @ViewBuilder
    private func entityChips(for moment: Moment) -> some View {
        let placeNames = places(in: moment)
        let themeNames = moment.tags
        let people = store.people(in: moment.id)
        let tasks = store.tasks(from: moment.id)
        let hasAny = !placeNames.isEmpty || !themeNames.isEmpty
            || !people.isEmpty || !tasks.isEmpty
        if hasAny {
            VStack(alignment: .leading, spacing: 18) {
                if !placeNames.isEmpty {
                    extractedGroup("Location", chips: placeNames.map { ExtractedChip.place($0) })
                }
                if !themeNames.isEmpty {
                    extractedGroup("Themes", chips: themeNames.map { ExtractedChip.theme($0) })
                }
                if !people.isEmpty {
                    extractedGroup("People", chips: people.map { ExtractedChip.person($0) })
                }
                if !tasks.isEmpty {
                    extractedGroup("Tasks", chips: tasks.map { ExtractedChip.task($0) })
                }
            }
        }
    }

    private func extractedGroup(_ label: String, chips: [ExtractedChip]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.micro())
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.tertiaryText)
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(chips) { chip in
                    ExtractedChipView(chip: chip)
                }
            }
        }
    }

    /// Locations tied to this moment: its explicit `place`, plus any
    /// hand-curated places mentioned in its text. Deduped, explicit first.
    private func places(in moment: Moment) -> [String] {
        var result: [String] = []
        if let p = moment.place { result.append(p) }
        for place in store.places where !result.contains(place) {
            let mentioned = moment.title.localizedCaseInsensitiveContains(place)
                || moment.polishedSummary.localizedCaseInsensitiveContains(place)
                || moment.rawTranscript.localizedCaseInsensitiveContains(place)
            if mentioned { result.append(place) }
        }
        return result
    }

    private func sourceLabel(_ source: MomentSource) -> String {
        switch source {
        case .necklace: return "Necklace"
        case .phone: return "Phone"
        }
    }
}

private struct MomentAskSeed: Identifiable {
    let query: String
    var id: String { query }
}

private enum ExtractedChip: Identifiable {
    case place(String)
    case theme(String)
    case person(Person)
    case task(TaskItem)

    var id: String {
        switch self {
        case .place(let p):  return "place-\(p)"
        case .theme(let t):  return "theme-\(t)"
        case .person(let p): return "person-\(p.id)"
        case .task(let t):   return "task-\(t.id)"
        }
    }

    var label: String {
        switch self {
        case .place(let p):  return p
        case .theme(let t):  return t
        case .person(let p): return p.name
        case .task(let t):   return t.text
        }
    }

    var systemImage: String {
        switch self {
        case .place:         return "location.fill"
        case .theme:         return "number"
        case .person:        return "person.circle"
        case .task:          return "checklist"
        }
    }
}

private struct ExtractedChipView: View {
    let chip: ExtractedChip

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: chip.systemImage)
                .font(.system(size: 12, weight: .regular))
            Text(chip.label)
                .font(Theme.caption())
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous).fill(Theme.accentSoft)
        )
        .foregroundStyle(Theme.primaryText)
    }
}
