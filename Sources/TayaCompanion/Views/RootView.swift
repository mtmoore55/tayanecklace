import SwiftUI
import TayaIntelligence

public struct RootView: View {
    @State private var selection: AppTab = .today
    @State private var progress: Double = Double(AppTab.today.index)
    @State private var showSplash: Bool = true
    @State private var ambient: AmbientState = AmbientState(
        userInitial: "E",
        necklaceBattery: 72,
        weather: .sunny
    )

    // Composer state
    @State private var composerText: String = ""
    @State private var showAddMenu: Bool = false
    @State private var showCaptureSheet: Bool = false
    @State private var showAddNoteSheet: Bool = false

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
        .confirmationDialog(
            "Add",
            isPresented: $showAddMenu,
            titleVisibility: .hidden
        ) {
            Button("Capture a moment") { showCaptureSheet = true }
            Button("Add a note manually") { showAddNoteSheet = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCaptureSheet) { CaptureSheet() }
        .sheet(isPresented: $showAddNoteSheet) { AddNoteSheet() }
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
                text: $composerText,
                onSubmit: { /* Phase 3: send to chat */ },
                onPlusTap: { showAddMenu = true }
            )
            .background(Theme.background.ignoresSafeArea(edges: .bottom))
        }
    }
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
