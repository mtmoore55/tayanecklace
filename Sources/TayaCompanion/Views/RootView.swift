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

    /// Single sheet route for everything RootView presents. SwiftUI's
    /// behavior with multiple `.sheet` modifiers on one view is unreliable
    /// (re-presentation, double `onAppear`) — funneling capture, device,
    /// and chat through one item-binding keeps presentation deterministic.
    @State private var sheet: RootSheet?

    // User-chosen colorway. `auto` follows time-of-day; set from the
    // Profile sheet. Drives `preferredColorScheme` below.
    @State private var appearance: AppearanceMode = .auto

    // Which lens the Home Mirror presents. Set from the Profile sheet;
    // a preview control for now (see `MirrorLens`).
    @State private var mirrorLens: MirrorLens = .reflection

    // Push-notification opt-ins, surfaced in the Profile sheet. Defaults
    // are all-on; production wires these into the real APNs registration
    // and per-category server-side gating.
    @State private var notifications = NotificationPreferences()

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
                ambient.lastSyncedAt = Date()
                store.appendSyncedContent()
            }
        }
        // When the demo connectivity toggle flips back to `.ok`, drain
        // any captures that landed while offline. Replace this with the
        // real reachability signal in production.
        .onChange(of: ambient.connectivity) { old, new in
            if old != .ok, new == .ok {
                Task {
                    try? await Task.sleep(for: .milliseconds(800))
                    withAnimation(.easeInOut(duration: 0.3)) {
                        store.flushPendingMoments()
                        ambient.lastSyncedAt = Date()
                    }
                }
            }
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            HomeView(
                ambient: ambient,
                appearance: $appearance,
                mirrorLens: $mirrorLens,
                connectivity: $ambient.connectivity,
                batteryPercent: $ambient.necklaceBattery,
                isCharging: $ambient.isCharging,
                notifications: $notifications
            )

            gradientVeil

            AskCaptureBarLauncher(
                onActivate: { sheet = .chat(autoStartRecording: false) },
                onMicActivate: { sheet = .chat(autoStartRecording: true) },
                onCapture: { sheet = .capture }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .overlay(alignment: .top) {
            StatusBanner(
                ambient: ambient,
                onRetry: {
                    // Demo: flip back to `.ok`. Production wires this to
                    // a BLE rescan / sync retry / reachability re-check.
                    // Only connectivity copy uses Retry — battery-critical
                    // has its own dismiss button.
                    withAnimation(.easeInOut(duration: 0.3)) {
                        ambient.connectivity = .ok
                    }
                },
                onTap: {
                    // Necklace + sync variants drop the user into the
                    // hardware details sheet; network variant is a no-op.
                    // Battery-critical also opens the sheet.
                    if ambient.connectivity == .networkUnreachable { return }
                    sheet = .device
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .capture:
                CaptureSheet(connectivity: ambient.connectivity)
                    .environment(store)
            case .device:
                NecklaceDeviceSheet(ambient: ambient)
            case .chat(let autoStartRecording):
                ChatSheet(autoStartRecording: autoStartRecording)
                    .environment(store)
            }
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

/// Single presentation route for RootView's sheet — see `sheet` in
/// `RootView`. Identifiable via the case (and recording flag) so SwiftUI
/// treats `.chat(autoStartRecording: true)` as a distinct presentation from
/// `.chat(autoStartRecording: false)`.
enum RootSheet: Identifiable, Hashable {
    case capture
    case device
    case chat(autoStartRecording: Bool)

    var id: String {
        switch self {
        case .capture:                          return "capture"
        case .device:                           return "device"
        case .chat(let auto):                   return "chat-\(auto)"
        }
    }
}

#Preview {
    RootView()
        .environment(DataStore.seeded(now: Date()))
}
