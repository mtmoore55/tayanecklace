import SwiftUI

struct UserView: View {
    @Environment(\.gesturePhase) private var gesturePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Profile")
                    .font(Theme.screenTitle())
                    .padding(.top, 12)

                Card {
                    Text("Profile placeholder — account, preferences, and notifications land here in Phase 3.")
                        .font(Theme.body())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
    }
}

#Preview {
    UserView()
        .environment(DataStore.seeded(now: Date()))
}
