import SwiftUI
import TayaIntelligence

public struct RootView: View {
    @Environment(DataStore.self) private var store
    @State private var selection: AppTab = .today
    @State private var progress: Double = Double(AppTab.today.index)
    @State private var showSplash: Bool = true
    @State private var ambient: AmbientState = AmbientState(
        userInitial: "E",
        necklaceBattery: 72,
        weather: .sunny,
        isNight: AmbientState.isCurrentlyNight()
    )

    // Composer state
    @State private var showCaptureSheet: Bool = false
    @State private var showAddNoteSheet: Bool = false
    @State private var showNewChat: Bool = false

    public init() {
        AppFonts.register()
    }

    private var pages: [AnyView] {
        [
            AnyView(UserView()),
            AnyView(NecklaceView()),
            AnyView(HomeView(ambient: ambient)),
            AnyView(ChatView()),
            AnyView(MomentsView()),
        ]
    }

    public var body: some View {
        ZStack {
            mainContent

            if showSplash {
                SplashView(onFinish: {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        showSplash = false
                    }
                })
                .transition(.opacity)
            }
        }
        .task {
            // First-launch sync demo: necklace nav morphs into a sync chip
            // with a rotating icon + "N of 2" counter. When it completes,
            // the freshly-pulled content drops into the DataStore so the
            // Today view fills in below.
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.4)) {
                ambient.sync = .syncing(current: 1, total: 2)
            }
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.25)) {
                ambient.sync = .syncing(current: 2, total: 2)
            }
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeInOut(duration: 0.4)) {
                ambient.sync = .idle
                store.appendSyncedContent()
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            TayaTopNav(
                progress: progress,
                ambient: ambient,
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
            .overlay(alignment: .top) { topFadeGradient }
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) { composerArea }
        .sheet(isPresented: $showCaptureSheet) { CaptureSheet() }
        .sheet(isPresented: $showAddNoteSheet) { AddNoteSheet() }
        .sheet(isPresented: $showNewChat) { NewChatSheet() }
        .tint(Theme.accent)
    }

    // MARK: - Chrome overlays

    /// Gradient at the top of the pager: opaque (Theme.background) at the
    /// nav's bottom edge → transparent below. Cards scrolling up pass
    /// behind this and fade out smoothly instead of hitting a hard line.
    private var topFadeGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.background, location: 0.0),
                .init(color: Theme.background.opacity(0), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: Theme.topFadeHeight)
        .allowsHitTesting(false)
    }

    /// Composer pinned to the bottom with a gradient fade above it.
    /// Background extends down through the home-indicator safe area so
    /// there's no visible seam.
    private var composerArea: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Theme.background.opacity(0), location: 0.0),
                    .init(color: Theme.background, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Theme.bottomFadeHeight)
            .allowsHitTesting(false)

            AskTayaComposer(
                onOpenChat: { showNewChat = true },
                onCapture: { showCaptureSheet = true },
                onAddNote: { showAddNoteSheet = true }
            )
            .background(Theme.background.ignoresSafeArea(edges: .bottom))
        }
    }
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
