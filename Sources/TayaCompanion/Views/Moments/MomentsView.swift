import SwiftUI
import TayaIntelligence

/// Moments tab — the chronological list of everything the necklace and
/// phone have captured. Grouped by day, glass-card per day. This is the
/// "Vault" surface the team discussed; clock icon in the bottom nav.
struct MomentsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedMoment: MomentRoute?
    @State private var showExport = false
    /// Bumped by `RootView` when the Moments tab is tapped — scrolls back
    /// to the top of the list.
    var resetToken: Int = 0

    private static let scrollTopID = "moments-scroll-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    ForEach(grouped, id: \.key) { group in
                        section(group)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, Theme.pageContentTopInset)
                .padding(.bottom, Theme.pageContentBottomInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(Self.scrollTopID)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollDisabled(gesturePhase == .horizontalSwipe)
            .onChange(of: resetToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(Self.scrollTopID, anchor: .top)
                }
            }
            .sheet(item: $presentedMoment) { route in
                MomentDetailView(momentID: route.id)
                    .environment(store)
            }
            .sheet(isPresented: $showExport) {
                MomentsExportSheet()
                    .environment(store)
            }
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
                guard gesturePhase == .idle else { return }
                showExport = true
            } label: {
                ShareGlassLabel(size: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Export moments")
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
