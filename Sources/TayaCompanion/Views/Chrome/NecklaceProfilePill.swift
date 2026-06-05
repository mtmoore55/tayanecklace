import SwiftUI

/// Top-right glass surface that combines necklace battery and the user's
/// avatar. Has two forms:
///
/// - **Compact**: a corner capsule with the battery glyph + avatar. The
///   day-to-day resting state. The battery tap reveals the hardware area;
///   the avatar opens the Profile sheet.
/// - **Expanded**: a full-width capsule that *replaces the battery half*
///   when an active hardware/environment alert needs attention. Shows the
///   alert icon + title + subtitle + a trailing retry/dismiss action. The
///   avatar stays right-anchored and independently tappable so the user
///   can still reach Profile while the alert is up.
///
/// One container holds both forms: only the inner content swaps. The
/// Capsule, the glass material, and the avatar are continuous across the
/// morph, so collapsing back feels like the glass relaxing into its
/// resting shape rather than a hard view switch.
///
/// Expansion is driven entirely by `ambient` + `batteryAlertDismissed`.
/// HomeView reads `hasActiveStatus(for:batteryDismissed:)` to know whether
/// to hide the greeting beneath the expanded capsule.
struct NecklaceProfilePill: View {
    let ambient: AmbientState
    /// Per-episode dismissal flag for the battery-critical alert. HomeView
    /// owns the state so it can hide the greeting in sync with expansion.
    @Binding var batteryAlertDismissed: Bool
    var onRevealHardware: () -> Void
    var onRetry: () -> Void
    var onOpenProfile: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    private let compactHeight: CGFloat = 44
    private let avatarSize: CGFloat = 36

    /// Whether the pill is currently in expanded status form. Mirrored
    /// here as a static so HomeView can drive the greeting's visibility
    /// off the same source of truth.
    static func hasActiveStatus(
        for ambient: AmbientState,
        batteryDismissed: Bool
    ) -> Bool {
        currentCopy(for: ambient, batteryDismissed: batteryDismissed) != nil
    }

    private var copy: Copy? {
        Self.currentCopy(for: ambient, batteryDismissed: batteryAlertDismissed)
    }

    private var isExpanded: Bool { copy != nil }

    var body: some View {
        HStack(spacing: 10) {
            if let copy = copy {
                expandedLeading(copy)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .leading)))
                trailingAction(for: copy.action)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))
            } else {
                compactBatteryButton
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))
            }

            avatarButton
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(height: compactHeight)
        .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .trailing)
        .tayaGlassCard(in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(TayaColors.warningAmber.opacity(0.35), lineWidth: 0.75)
                .opacity(isExpanded ? 1 : 0)
        )
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: isExpanded)
        .onChange(of: ambient.batteryDisplayState) { _, new in
            // Reset dismissal when the underlying state leaves `.critical`,
            // so the alert reappears on the next critical episode.
            if new != .critical { batteryAlertDismissed = false }
        }
    }

    // MARK: - Compact (resting) content

    private var compactBatteryButton: some View {
        Button(action: onRevealHardware) {
            batteryGlyph
                .frame(minWidth: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Necklace \(ambient.necklaceBattery) percent. Tap for hardware.")
    }

    @ViewBuilder
    private var batteryGlyph: some View {
        if case .syncing(let current, let total) = ambient.sync {
            HStack(spacing: 6) {
                TimelineView(.animation(paused: scenePhase != .active)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let angle = (t * 360.0 / 1.1).truncatingRemainder(dividingBy: 360)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.accent)
                        .rotationEffect(.degrees(angle))
                }
                Text("\(current) of \(total)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
        } else {
            batteryStateGlyph
        }
    }

    @ViewBuilder
    private var batteryStateGlyph: some View {
        let symbol = batterySystemImage(
            forPercent: ambient.necklaceBattery,
            isCharging: ambient.isCharging
        )
        let tint = batteryGlyphTint
        let base = Image(systemName: symbol)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(tint)

        if ambient.batteryDisplayState == .critical {
            // Slow opacity pulse — present without being alarming.
            TimelineView(.animation(paused: scenePhase != .active)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = (sin(t * 2 * .pi * 0.5) + 1) / 2   // 0…1 at 0.5 Hz
                base.opacity(0.55 + 0.45 * phase)
            }
        } else {
            base
        }
    }

    private var batteryGlyphTint: Color {
        switch ambient.batteryDisplayState {
        case .low, .critical: return TayaColors.warningAmber
        case .charging, .full, .healthy: return Theme.accent
        }
    }

    // MARK: - Expanded (alert) content

    private func expandedLeading(_ copy: Copy) -> some View {
        // Tappable message area — opens hardware for device-related
        // states; no-op when the issue is the network (the hardware
        // can't fix that).
        Button(action: {
            if !copy.isNetwork { onRevealHardware() }
        }) {
            HStack(spacing: 10) {
                Image(systemName: copy.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TayaColors.warningAmber)
                    .frame(width: 20)
                Text(copy.title)
                    .font(Theme.bodyL().weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer(minLength: 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.title)
    }

    @ViewBuilder
    private func trailingAction(for action: Copy.Action) -> some View {
        switch action {
        case .retry(let label):
            Button {
                Haptics.tap()
                onRetry()
            } label: {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TayaColors.warningAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(TayaColors.warningAmber.opacity(0.18))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(TayaColors.warningAmber.opacity(0.5), lineWidth: 0.75)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        case .dismissBattery:
            Button {
                Haptics.tap()
                batteryAlertDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TayaColors.warningAmber)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(TayaColors.warningAmber.opacity(0.18))
                    )
                    .overlay(
                        Circle().stroke(TayaColors.warningAmber.opacity(0.5), lineWidth: 0.75)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
    }

    // MARK: - Avatar (shared by both forms)

    private var avatarButton: some View {
        Button(action: onOpenProfile) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.92))
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                Text(ambient.userInitial)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TayaColors.oxfordBlue)
            }
            .frame(width: avatarSize, height: avatarSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    // MARK: - Status copy

    /// Highest-priority active alert, if any. Connectivity wins over
    /// battery; battery only fires at `.critical` and respects the
    /// per-episode dismissal flag.
    private static func currentCopy(
        for ambient: AmbientState,
        batteryDismissed: Bool
    ) -> Copy? {
        if ambient.connectivity != .ok {
            return Copy.for(connectivity: ambient.connectivity)
        }
        if ambient.batteryDisplayState == .critical, !batteryDismissed {
            return Copy.batteryCritical(percent: ambient.necklaceBattery)
        }
        return nil
    }

    struct Copy {
        enum Action {
            case retry(label: String)
            case dismissBattery
        }

        let icon: String
        let title: String
        let action: Action
        let isNetwork: Bool

        static func `for`(connectivity status: ConnectivityStatus) -> Copy? {
            switch status {
            case .ok:
                return nil
            case .necklaceUnreachable:
                return Copy(
                    icon: "bolt.horizontal.circle",
                    title: "Necklace not connected",
                    action: .retry(label: "Retry"),
                    isNetwork: false
                )
            case .networkUnreachable:
                return Copy(
                    icon: "wifi.slash",
                    title: "You're offline",
                    action: .retry(label: "Retry"),
                    isNetwork: true
                )
            case .syncFailed:
                return Copy(
                    icon: "exclamationmark.arrow.triangle.2.circlepath",
                    title: "Sync didn't complete",
                    action: .retry(label: "Retry"),
                    isNetwork: false
                )
            }
        }

        // Folds the percent into the title now that the subtitle (where
        // the percent used to live) is gone.
        static func batteryCritical(percent: Int) -> Copy {
            Copy(
                icon: "battery.0percent",
                title: "Battery at \(percent)%",
                action: .dismissBattery,
                isNetwork: false
            )
        }
    }
}

#Preview("Compact") {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        VStack {
            HStack {
                Spacer()
                NecklaceProfilePill(
                    ambient: .mock,
                    batteryAlertDismissed: .constant(false),
                    onRevealHardware: {},
                    onRetry: {},
                    onOpenProfile: {}
                )
            }
            .padding()
            Spacer()
        }
    }
}

#Preview("Expanded — states") {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 16) {
            NecklaceProfilePill(
                ambient: AmbientState(connectivity: .necklaceUnreachable),
                batteryAlertDismissed: .constant(false),
                onRevealHardware: {},
                onRetry: {},
                onOpenProfile: {}
            )
            NecklaceProfilePill(
                ambient: AmbientState(connectivity: .networkUnreachable),
                batteryAlertDismissed: .constant(false),
                onRevealHardware: {},
                onRetry: {},
                onOpenProfile: {}
            )
            NecklaceProfilePill(
                ambient: AmbientState(connectivity: .syncFailed),
                batteryAlertDismissed: .constant(false),
                onRevealHardware: {},
                onRetry: {},
                onOpenProfile: {}
            )
            NecklaceProfilePill(
                ambient: AmbientState(necklaceBattery: 4),
                batteryAlertDismissed: .constant(false),
                onRevealHardware: {},
                onRetry: {},
                onOpenProfile: {}
            )
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
}
