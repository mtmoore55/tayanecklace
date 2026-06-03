import SwiftUI

public struct RootView: View {
    @Environment(DataStore.self) private var store
    @State private var showSplash: Bool = true
    @State private var ambient: AmbientState = AmbientState(
        userInitial: "E",
        necklaceBattery: 72,
        weather: .sunny,
        isNight: AmbientState.isCurrentlyNight()
    )

    /// Chat experience now lives in `ChatSheet` (a bottom sheet matching
    /// the rest of the app's detail surfaces). RootView only routes the
    /// presentation; the sheet owns its composer, thread, and dictation
    /// state.
    @State private var chatSheet: ChatSheetRoute?

    // Mic on the AskCaptureBar presents this — capture is otherwise
    // detached from the chat flow.
    @State private var showCaptureSheet: Bool = false

    // User-chosen colorway. `auto` follows time-of-day; set from the
    // Profile sheet. Drives `preferredColorScheme` below.
    @State private var appearance: AppearanceMode = .auto

    // Which lens the Home Mirror presents. Set from the Profile sheet;
    // a preview control for now (see `MirrorLens`).
    @State private var mirrorLens: MirrorLens = .reflection

    public init() {
        AppFonts.register()
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
            HomeView(ambient: ambient, appearance: $appearance, mirrorLens: $mirrorLens)

            gradientVeil

            AskCaptureBarLauncher(
                onActivate: { chatSheet = ChatSheetRoute(autoStartRecording: false) },
                onMicActivate: { chatSheet = ChatSheetRoute(autoStartRecording: true) },
                onCapture: { showCaptureSheet = true }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $showCaptureSheet) { CaptureSheet() }
        .sheet(item: $chatSheet) { route in
            ChatSheet(autoStartRecording: route.autoStartRecording)
                .environment(store)
        }
        .tint(Theme.accent)
    }

    // MARK: - Gradient veil

    /// A copy of the page gradient overlaid at the bottom, masked to
    /// fade in over ~180pt. Same `Theme.backgroundGradient` rendered
    /// with `.ignoresSafeArea()`, so every pixel matches the bg behind
    /// it — visually it just *is* the gradient. Hides page content that
    /// would otherwise scroll up through the AskCaptureBar area.
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
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
