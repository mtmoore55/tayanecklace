import SwiftUI

/// Moments timeline — the chronological list of everything the necklace
/// and phone have captured. Grouped by day, glass-card per day.
/// Presented as a sheet from Home's "Moments — See all" affordance;
/// dismissed via the drag handle rather than a Done button.
struct MomentsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedMoment: MomentRoute?
    @State private var showExport = false
    @State private var showRecentlyDeleted = false
    @State private var query: String = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                titleRow
                searchBar

                if grouped.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(grouped, id: \.key) { group in
                            section(group)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .onAppear { store.purgeExpiredDeletedMoments() }
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route)
                .environment(store)
        }
        .sheet(isPresented: $showExport) {
            MomentsExportSheet()
                .environment(store)
        }
        .sheet(isPresented: $showRecentlyDeleted) {
            RecentlyDeletedMomentsSheet().environment(store)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Button {
                showExport = true
            } label: {
                ShareGlassLabel(size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export moments")

            Menu {
                Button {
                    Haptics.tap()
                    showRecentlyDeleted = true
                } label: {
                    Label("Recently deleted", systemImage: "trash.slash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .tayaGlassCard(in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("More actions")
        }
    }

    private var titleRow: some View {
        Text("Moments")
            .font(Theme.greeting())
            .foregroundStyle(Theme.primaryText)
            .lineSpacing(-10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Glass-capsule keyword search. Filters titles, summaries,
    /// transcripts, tags, and the explicit place field.
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            TextField("", text: $query, prompt:
                Text("Search moments").foregroundStyle(Theme.secondaryText)
            )
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .tayaGlassCard(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No moments match \u{201C}\(query)\u{201D}")
                .font(Theme.bodyL())
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    @ViewBuilder
    private func section(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.label)
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)

            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(group.moments.enumerated()), id: \.element.id) { index, moment in
                        Button {
                            guard gesturePhase == .idle else { return }
                            presentedMoment = MomentRoute(ids: allMomentIDs, startID: moment.id)
                        } label: {
                            MomentRow(
                                moment: moment,
                                timeFormat: .timeOnly,
                                onDelete: {
                                    withAnimation(.snappy) { store.deleteMoment(moment) }
                                }
                            )
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if index < group.moments.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                                .overlay(Theme.glassStroke.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grouping

    private struct DayGroup {
        let key: Date
        let label: String
        let moments: [Moment]
    }

    private var grouped: [DayGroup] {
        let cal = Calendar.current
        let source = filteredMoments
        let buckets = Dictionary(grouping: source) { cal.startOfDay(for: $0.createdAt) }
        return buckets.keys.sorted(by: >).map { day in
            DayGroup(
                key: day,
                label: RelativeDay.sectionLabel(from: day),
                moments: buckets[day]!.sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    /// All active moments, narrowed by the search query. Case-insensitive
    /// match across title, polished summary, raw transcript, tags, and
    /// the explicit place field.
    private var filteredMoments: [Moment] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.activeMoments }
        return store.activeMoments.filter { moment in
            moment.title.localizedCaseInsensitiveContains(q)
                || moment.polishedSummary.localizedCaseInsensitiveContains(q)
                || moment.rawTranscript.localizedCaseInsensitiveContains(q)
                || (moment.place?.localizedCaseInsensitiveContains(q) ?? false)
                || moment.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) })
        }
    }

    /// Flat newest-first IDs across all day groups — the order the user
    /// sees as they scroll, so swiping in the detail follows the same
    /// rhythm and crosses day boundaries naturally.
    private var allMomentIDs: [Moment.ID] {
        grouped.flatMap { $0.moments.map(\.id) }
    }
}

#Preview {
    MomentsView()
        .background(Theme.backgroundGradient)
        .environment(DataStore.seeded(now: Date()))
}
