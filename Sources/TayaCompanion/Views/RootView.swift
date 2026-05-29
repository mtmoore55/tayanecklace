import SwiftUI
import TayaIntelligence

public struct RootView: View {
    @Environment(DataStore.self) private var store
    @State private var selection: AppTab = .home
    @State private var progress: Double = Double(AppTab.home.index)
    @State private var showSplash: Bool = true
    @State private var ambient: AmbientState = AmbientState(
        userInitial: "E",
        necklaceBattery: 72,
        weather: .sunny,
        isNight: AmbientState.isCurrentlyNight()
    )

    // Sheets driven from the Plus button.
    @State private var showCaptureSheet: Bool = false
    @State private var showAddNoteSheet: Bool = false
    @State private var showAddTaskSheet: Bool = false

    // Bumped whenever a tab icon is tapped — each tab view watches its
    // token to reset to the default scroll position (and Home also
    // collapses the necklace hardware panel back to the default view).
    // Chat additionally watches it to fold the active chat surface back
    // down into past-chats browsing, both on tab-icon tap and on swipe
    // away (driven by the `.onChange(of: selection)` below).
    @State private var homeResetToken: Int = 0
    @State private var chatResetToken: Int = 0
    @State private var momentsResetToken: Int = 0

    // Mirrored from `ChatTabView` via PreferenceKey: true while the
    // user is composing or in an active chat thread. Drives the bottom
    // chrome's opacity so the writing surface gets the screen alone.
    @State private var isChatActive: Bool = false

    // User-chosen colorway. `auto` follows time-of-day; set from the
    // Profile sheet. Drives `preferredColorScheme` below.
    @State private var appearance: AppearanceMode = .auto

    // Which lens the Home Mirror presents. Set from the Profile sheet;
    // a preview control for now (see `MirrorLens`).
    @State private var mirrorLens: MirrorLens = .reflection

    public init() {
        AppFonts.register()
    }

    private var pages: [AnyView] {
        [
            AnyView(HomeView(ambient: ambient, resetToken: homeResetToken, appearance: $appearance, mirrorLens: $mirrorLens)),
            AnyView(ChatTabView(resetToken: chatResetToken)),
            AnyView(MomentsView(resetToken: momentsResetToken)),
        ]
    }

    public var body: some View {
        ZStack {
            // Big blue gradient sits behind everything. Pages should be
            // transparent so it shows through.
            Theme.backgroundGradient
                .ignoresSafeArea()

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
        // Appearance preference (Auto follows time-of-day) drives the
        // colorway. Dynamic Theme tokens follow.
        .preferredColorScheme(appearance.colorScheme(isNight: ambient.isNight))
        .task {
            // First-launch sync demo. The sync state flows through the
            // inline necklace card on Home (battery → rotating orb).
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
        ZStack(alignment: .bottom) {
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

            gradientVeil

            bottomChrome
                .opacity(isChatActive ? 0 : 1)
                .allowsHitTesting(!isChatActive)
                .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isChatActive)
        }
        .onPreferenceChange(ChatActivePreferenceKey.self) { newValue in
            isChatActive = newValue
        }
        .sheet(isPresented: $showCaptureSheet) { CaptureSheet() }
        .sheet(isPresented: $showAddNoteSheet) { AddNoteSheet() }
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskSheet().environment(store)
        }
        .tint(Theme.accent)
        .onChange(of: selection) { oldValue, newValue in
            // Leaving the Chat tab — by tap, by swipe, or by selection
            // change of any kind — folds the active chat surface back to
            // browsing on next visit.
            if oldValue == .chat && newValue != .chat {
                chatResetToken += 1
            }
        }
    }

    // MARK: - Gradient veil

    /// A copy of the page gradient overlaid at the bottom, masked to
    /// fade in over ~180pt. Same `Theme.backgroundGradient` rendered
    /// with `.ignoresSafeArea()`, so every pixel matches the bg behind
    /// it — visually it just *is* the gradient. Hides page content that
    /// would otherwise scroll up through the tab area.
    private var gradientVeil: some View {
        Theme.backgroundGradient
            .ignoresSafeArea()
            .mask(
                VStack(spacing: 0) {
                    Color.clear
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.0),
                            .init(color: Color.black, location: 0.45),
                            .init(color: Color.black, location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                }
                .ignoresSafeArea()
            )
            .allowsHitTesting(false)
    }

    // MARK: - Bottom chrome

    /// No background fade — the page gradient flows uninterrupted to
    /// the screen bottom, so the chrome doesn't read as a separate
    /// rectangle. Page content stops well above the icons (see
    /// `pageContentBottomInset`) so nothing scrolls under them.
    ///
    /// The Chat tab now owns its own composer (lives inside
    /// `ChatTabView`), so the chrome is just the nav row + Plus button.
    private var bottomChrome: some View {
        HStack {
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                TayaBottomNav(
                    progress: $progress,
                    onSelect: { tab in
                        selection = tab
                        // Tapping any tab icon returns that view to its
                        // default scroll position (Home also collapses the
                        // hardware panel).
                        switch tab {
                        case .home:    homeResetToken += 1
                        case .chat:    chatResetToken += 1
                        case .moments: momentsResetToken += 1
                        }
                    }
                )
                PlusButton(
                    onCapture: { showCaptureSheet = true },
                    onAddNote: { showAddNoteSheet = true },
                    onAddTask: { showAddTaskSheet = true }
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
    }
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
