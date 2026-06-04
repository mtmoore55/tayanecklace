import SwiftUI

/// Top-of-screen status strip. Surfaces the highest-priority device or
/// environment issue — connectivity wins over battery, battery only fires
/// at `.critical`. Glass capsule with an amber accent; copy + icon vary
/// by case.
///
/// Trailing affordance depends on the kind of alert:
/// - **Connectivity**: a `Retry` pill the host wires to BLE rescan / sync
///   retry / reachability re-check. Sticky until the underlying state
///   clears.
/// - **Battery critical**: a small dismiss button. The state is purely
///   informational — there's nothing for the app to "retry." Dismissal is
///   per-episode: once `batteryDisplayState` leaves `.critical` and comes
///   back, the banner shows fresh.
struct StatusBanner: View {
    let ambient: AmbientState
    var onRetry: () -> Void = {}
    var onTap: () -> Void = {}

    /// Per-episode dismissal flag for the battery-critical alert. Reset
    /// whenever the underlying state stops being `.critical`, so the banner
    /// reappears on the next critical episode.
    @State private var batteryAlertDismissed = false

    var body: some View {
        Group {
            if let copy = currentCopy {
                content(copy)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal:   .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: ambient.connectivity)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: ambient.batteryDisplayState)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: batteryAlertDismissed)
        .onChange(of: ambient.batteryDisplayState) { _, new in
            if new != .critical { batteryAlertDismissed = false }
        }
    }

    private var currentCopy: Copy? {
        if ambient.connectivity != .ok {
            return Copy.for(connectivity: ambient.connectivity)
        }
        if ambient.batteryDisplayState == .critical, !batteryAlertDismissed {
            return Copy.batteryCritical(percent: ambient.necklaceBattery)
        }
        return nil
    }

    private func content(_ copy: Copy) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: copy.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TayaColors.warningAmber)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.title)
                        .font(Theme.bodyL().weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(copy.subtitle)
                        .font(Theme.bodyS())
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                trailingAction(for: copy.action)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .tayaGlassCard(in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(TayaColors.warningAmber.opacity(0.35), lineWidth: 0.75)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.subtitle)")
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
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    batteryAlertDismissed = true
                }
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

    private struct Copy {
        enum Action {
            case retry(label: String)
            case dismissBattery
        }

        let icon: String
        let title: String
        let subtitle: String
        let action: Action

        static func `for`(connectivity status: ConnectivityStatus) -> Copy? {
            switch status {
            case .ok:
                return nil
            case .necklaceUnreachable:
                return Copy(
                    icon: "bolt.horizontal.circle",
                    title: "Necklace not connected",
                    subtitle: "Captures save here and sync later.",
                    action: .retry(label: "Retry")
                )
            case .networkUnreachable:
                return Copy(
                    icon: "wifi.slash",
                    title: "You're offline",
                    subtitle: "Moments will sync when you're back.",
                    action: .retry(label: "Retry")
                )
            case .syncFailed:
                return Copy(
                    icon: "exclamationmark.arrow.triangle.2.circlepath",
                    title: "Sync didn't complete",
                    subtitle: "A few moments are waiting to sync.",
                    action: .retry(label: "Retry")
                )
            }
        }

        static func batteryCritical(percent: Int) -> Copy {
            Copy(
                icon: "battery.0percent",
                title: "Battery almost empty",
                subtitle: "Charge soon — your necklace is at \(percent)%.",
                action: .dismissBattery
            )
        }
    }
}

#Preview("All states") {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 16) {
            StatusBanner(ambient: AmbientState(connectivity: .necklaceUnreachable))
            StatusBanner(ambient: AmbientState(connectivity: .networkUnreachable))
            StatusBanner(ambient: AmbientState(connectivity: .syncFailed))
            StatusBanner(ambient: AmbientState(necklaceBattery: 4))
            StatusBanner(ambient: .mock) // hidden
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }
}
