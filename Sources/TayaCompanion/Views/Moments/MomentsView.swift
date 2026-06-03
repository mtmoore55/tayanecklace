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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow
                titleRow

                VStack(alignment: .leading, spacing: 22) {
                    ForEach(grouped, id: \.key) { group in
                        section(group)
                    }
                }
                .padding(.top, 4)
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
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(route: route)
                .environment(store)
        }
        .sheet(isPresented: $showExport) {
            MomentsExportSheet()
                .environment(store)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                showExport = true
            } label: {
                ShareGlassLabel(size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export moments")
        }
    }

    private var titleRow: some View {
        Text("Moments")
            .font(Theme.greeting())
            .foregroundStyle(Theme.primaryText)
            .lineSpacing(-10)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                            MomentRow(moment: moment, timeFormat: .timeOnly)
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
        let buckets = Dictionary(grouping: store.moments) { cal.startOfDay(for: $0.createdAt) }
        return buckets.keys.sorted(by: >).map { day in
            DayGroup(
                key: day,
                label: RelativeDay.sectionLabel(from: day),
                moments: buckets[day]!.sorted { $0.createdAt > $1.createdAt }
            )
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
