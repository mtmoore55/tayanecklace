import SwiftUI

struct ChatView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.accent)

            Text("Ask anything")
                .font(Theme.sectionTitle())

            Text("Chat history lands here. \"Ask Taya\" composer at the bottom replaces the floating action button in Phase 2.")
                .font(Theme.body())
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    ChatView()
        .environment(DataStore.seeded(now: Date()))
}
