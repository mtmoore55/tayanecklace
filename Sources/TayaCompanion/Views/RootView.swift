import SwiftUI
import TayaIntelligence

public struct RootView: View {
    @State private var selection: AppTab = .today
    @State private var progress: Double = Double(AppTab.today.index)
    @State private var showSplash: Bool = true

    public init() {}

    private var pages: [AnyView] {
        [
            AnyView(UserView()),
            AnyView(NecklaceView()),
            AnyView(HomeView()),
            AnyView(ChatView()),
            AnyView(MomentsView()),
        ]
    }

    public var body: some View {
        ZStack {
            mainContent

            if showSplash {
                SplashView(onFinish: {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                })
                .transition(.opacity)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            TayaTopNav(
                progress: progress,
                onTap: { tab in
                    withAnimation(.interpolatingSpring(stiffness: 260, damping: 28)) {
                        selection = tab
                        progress = Double(tab.index)
                    }
                }
            )

            TayaPager(
                pages: pages,
                selection: Binding(
                    get: { selection.index },
                    set: { newIdx in
                        if let newTab = AppTab.at(newIdx) {
                            selection = newTab
                        }
                    }
                ),
                progress: $progress
            )
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
