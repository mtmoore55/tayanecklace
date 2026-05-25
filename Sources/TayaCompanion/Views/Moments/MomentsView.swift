import SwiftUI

struct MomentsView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.moments.prefix(8)) { moment in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(moment.title)
                                .font(Theme.cardTitle())
                            Text(moment.polishedSummary)
                                .font(Theme.body())
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(2)
                            Text(moment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(Theme.caption())
                                .foregroundStyle(Theme.secondaryText)
                                .padding(.top, 2)
                        }
                    }
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
    }
}

#Preview {
    MomentsView()
        .environment(DataStore.seeded(now: Date()))
}
