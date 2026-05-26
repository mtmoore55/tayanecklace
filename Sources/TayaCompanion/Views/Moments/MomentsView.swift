import SwiftUI

struct MomentsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedMoment: MomentRoute?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Moments")
                    .font(Theme.displayMedium())
                    .foregroundStyle(Theme.primaryText)

                ForEach(grouped, id: \.key) { group in
                    section(group)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, Theme.pageContentBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id)
                .environment(store)
        }
    }

    private func section(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.label)
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
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
                            Divider().padding(.leading, 44)
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
        .environment(DataStore.seeded(now: Date()))
}
