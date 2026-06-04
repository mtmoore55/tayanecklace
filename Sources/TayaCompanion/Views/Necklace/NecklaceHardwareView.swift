import SwiftUI

/// The necklace "hardware area" — a calm panel that lives one screen
/// *above* Home. Pulling down at the top of Home brings it into view.
///
/// Deliberately minimal for non-technical users: the USDZ hero, battery
/// percent + time remaining, and a single "Connected" status pill. The
/// technical specifics live behind that pill in a `NecklaceDeviceSheet`.
///
/// When `isExpanded` (fully revealed), a side-to-side drag rotates the
/// necklace within bounds, and the view captures horizontal swipes so the
/// pager doesn't switch tabs underneath it.
struct NecklaceHardwareView: View {
    let ambient: AmbientState
    var isExpanded: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var showDeviceSheet = false
    @State private var necklaceYaw: Double = 0

    /// Max rotation each way (degrees) and how many degrees per point of
    /// horizontal drag.
    private static let maxYaw: Double = 70
    private static let yawSensitivity: Double = 0.4

    /// Idle sway: a continuous ±25° rock. Driven by a `TimelineView`
    /// clock (a cosine) rather than a `repeatForever` animation — the
    /// latter silently stops when the panel re-renders during the reveal,
    /// whereas a clock-driven value is recomputed every frame and never
    /// stalls. Cosine eases to zero velocity at each extreme, so it
    /// "slows and pauses" at ±25 exactly as intended.
    private static let idleSwingAmplitude: Double = 25
    private static let idleSwingPeriod: Double = 7.0

    var body: some View {
        VStack(spacing: 0) {
            TayaWordmark(width: 96)
                .foregroundStyle(Theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.pageContentTopInset)

            // Position the content block at ~25% down the area below the
            // wordmark — half the gap that the previous vertically-centred
            // (1:1) layout produced. One leading spacer + three trailing
            // = a 1:3 weighting of the empty space.
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                // Only the hero re-renders each frame; the gesture and sheet
                // modifiers below stay on the stable VStack. The closure reads
                // the live `necklaceYaw` each frame, so a drag still tracks.
                TimelineView(.animation(paused: scenePhase != .active)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let phase = t * 2 * .pi / Self.idleSwingPeriod
                    let sway = cos(phase) * Self.idleSwingAmplitude
                    NecklaceHero(yaw: necklaceYaw + sway)
                }
                batteryReadout
                connectedPill
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .simultaneousGesture(rotateGesture)
        // Capture horizontal swipes only while expanded so the pager
        // defers (no tab switch) and the rotate drag owns the gesture.
        // Applied unconditionally (toggling `active`) to keep a stable
        // view identity — a structural `if` here double-rendered the
        // panel during the reveal animation.
        .capturesHorizontalSwipe(active: isExpanded)
        .sheet(isPresented: $showDeviceSheet) {
            NecklaceDeviceSheet(ambient: ambient)
        }
    }

    // MARK: - Rotation

    private func clampYaw(_ value: Double) -> Double {
        max(-Self.maxYaw, min(Self.maxYaw, value))
    }

    /// Side-to-side drag rotates the necklace within bounds; on release it
    /// springs back to its default forward-facing position.
    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                necklaceYaw = clampYaw(value.translation.width * Self.yawSensitivity)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    necklaceYaw = 0
                }
            }
    }

    // MARK: - Battery readout

    private var batteryReadout: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: batterySystemImage(forPercent: ambient.necklaceBattery, isCharging: ambient.isCharging))
                    .font(.system(size: 16, weight: .regular))
                Text("\(ambient.necklaceBattery)%")
                    .font(Theme.titleM())
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.primaryText)

            Text(timeRemainingLabel)
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var timeRemainingLabel: String {
        if ambient.isCharging { return "Charging" }
        switch ambient.batteryDisplayState {
        case .critical: return "Charge soon"
        case .low:      return "Low battery"
        default:
            let hours = Double(ambient.necklaceBattery) / 100.0 * 18.0
            return "~\(Int(hours)) hours remaining"
        }
    }

    // MARK: - Connected pill

    /// Subtle glass pill showing live connection status with an info glyph.
    /// Tapping opens the device-details sheet.
    private var connectedPill: some View {
        Button {
            showDeviceSheet = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(ambient.sync.isActive ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                Text(connectionLabel)
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.primaryText)
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .tayaGlassCard(in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(connectionLabel). Tap for device details.")
    }

    private var connectionLabel: String {
        if case .syncing(let c, let t) = ambient.sync { return "Syncing \(c) of \(t)" }
        return "Connected"
    }
}

// MARK: - 3D hero

/// Hosts the necklace USDZ above a soft cast shadow. `yaw` is driven by
/// the parent's rotate drag; the model itself rests still (no bob).
private struct NecklaceHero: View {
    var yaw: Double = 0

    private static let modelHeight: CGFloat = 210

    var body: some View {
        VStack(spacing: 14) {
            NecklaceModel(yawDegrees: yaw)
                .frame(maxWidth: .infinity)
                .frame(height: Self.modelHeight)

            shadow
        }
    }

    /// A soft cast shadow, darker than the background, blurred so its edges
    /// dissolve completely into the gradient.
    private var shadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.22))
            .frame(width: 150, height: 22)
            .blur(radius: 18)
            .frame(height: 22)
    }
}

#Preview {
    NecklaceHardwareView(ambient: .mock, isExpanded: true)
        .frame(maxHeight: .infinity)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .environment(DataStore.seeded(now: Date()))
}
