import SwiftUI
import TayaIntelligence

/// Moments timeline — the chronological list of everything the necklace
/// and phone have captured. Grouped by day, glass-card per day. Used to
/// be a tab; now presented as a sheet from Home's "Moments — See all"
/// affordance, so it owns its own Done button.
struct MomentsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @Environment(\.dismiss) private var dismiss
    @State private var presentedMoment: MomentRoute?
    @State private var showExport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                ForEach(grouped, id: \.key) { group in
                    section(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id)
                .environment(store)
        }
        .sheet(isPresented: $showExport) {
            MomentsExportSheet()
                .environment(store)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Moments")
                .font(Theme.greeting())
                .foregroundStyle(Theme.primaryText)
                .lineSpacing(-10)
            Spacer(minLength: 12)
            Button {
                showExport = true
            } label: {
                ShareGlassLabel(size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export moments")
            Button("Done") { dismiss() }
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 4)
        }
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
                            presentedMoment = MomentRoute(id: moment.id)
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
}

#Preview {
    MomentsView()
        .background(Theme.backgroundGradient)
        .environment(DataStore.seeded(now: Date()))
}
