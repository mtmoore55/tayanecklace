import SwiftUI

/// The Taya "intelligence" orb — a soft, diffuse blue cloud that doubles
/// as a brand mark and as a sync indicator.
///
/// Three native signals layered into one diffuse form (no geometric ring,
/// no progress bar — those would fight the cloud aesthetic):
///
/// - **Swirl** (activity): during `.pairing` and `.syncing`, the mesh blobs
///   shift from gentle linear sway to a slow circular orbit. The cloud
///   churns — "it's thinking."
/// - **Pulse** (discrete events): each time `current` advances within
///   `.syncing`, the whole cloud briefly expands and glows. One pulse per
///   note, countable at a glance.
/// - **Density** (cumulative): the mesh blobs' opacity scales with
///   `state.progress`. Idle is muted and airy; complete is saturated and
///   present. You can see the "before" vs. "after."
public struct TayaIntelligenceOrb: View {
    public let state: OrbState
    public let size: CGFloat

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseGlow: Double = 0.0
    @State private var activity: CGFloat = 0.0
    @State private var lastPulsedCount: Int = 0

    public init(state: OrbState, size: CGFloat = 80) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            mesh(t: t)
                .frame(width: size, height: size)
        }
        .scaleEffect(pulseScale)
        .shadow(
            color: TayaColors.skyBlue.opacity(pulseGlow * 0.55),
            radius: size * 0.3 * pulseGlow
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .onAppear {
            updateActivity(for: state, animated: false)
            lastPulsedCount = pulseCount(for: state)
        }
        .onChange(of: state) { _, newState in
            updateActivity(for: newState, animated: true)
            let newCount = pulseCount(for: newState)
            if newCount > lastPulsedCount {
                triggerPulse()
            }
            lastPulsedCount = newCount
        }
    }

    // MARK: - Mesh

    private func mesh(t: Double) -> some View {
        let breathe = 1.0 + 0.03 * sin(t * 1.3)
        let progress = state.progress

        return ZStack {
            // Outer halo — widest, softest, sets the perimeter falloff
            blob(color: TayaColors.skyBlue,
                 center: UnitPoint(x: 0.5, y: 0.5),
                 endRadius: size * 0.55)
                .offset(orbital(t: t, period: 8.0, radius: size * 0.04, phase: 0.0))
                .opacity(0.5 + progress * 0.2)

            // Deeper accent for dimensionality
            blob(color: TayaColors.oxfordBlue,
                 center: UnitPoint(x: 0.55, y: 0.6),
                 endRadius: size * 0.4)
                .offset(orbital(t: t, period: 6.0, radius: size * 0.05, phase: 2.1))
                .opacity(0.3 + progress * 0.3)

            // Bright core, slightly upper-left
            blob(color: TayaColors.skyBlue,
                 center: UnitPoint(x: 0.45, y: 0.42),
                 endRadius: size * 0.28)
                .offset(orbital(t: t, period: 5.0, radius: size * 0.04, phase: 4.2))
                .opacity(0.6 + progress * 0.35)
        }
        .scaleEffect(breathe)
        .blur(radius: size * 0.015)
        .animation(.easeOut(duration: 0.6), value: progress)
    }

    private func blob(color: Color, center: UnitPoint, endRadius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: center,
                    startRadius: 0,
                    endRadius: endRadius
                )
            )
    }

    /// Per-blob offset: blends idle "sway" with a circular orbit. `activity`
    /// (0→1, animated) crossfades between them so transitioning into/out of
    /// sync is smooth rather than a hard switch.
    private func orbital(t: Double, period: Double, radius: CGFloat, phase: Double) -> CGSize {
        let angle = t * (2 * .pi / period) + phase
        let idleX = sin(angle * 0.5) * radius * 0.6
        let idleY = cos(angle * 0.4) * radius * 0.6
        let orbitX = cos(angle) * radius * 1.3
        let orbitY = sin(angle) * radius * 1.3
        let a = Double(activity)
        return CGSize(
            width: idleX * (1 - a) + orbitX * a,
            height: idleY * (1 - a) + orbitY * a
        )
    }

    // MARK: - Activity & Pulse

    private func updateActivity(for state: OrbState, animated: Bool) {
        let target: CGFloat
        switch state {
        case .syncing:           target = 1.0
        case .pairing:           target = 0.55
        case .complete, .idle:   target = 0.0
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.7)) {
                activity = target
            }
        } else {
            activity = target
        }
    }

    private func pulseCount(for state: OrbState) -> Int {
        if case .syncing(let current, _) = state { return current }
        return 0
    }

    private func triggerPulse() {
        withAnimation(.easeOut(duration: 0.22)) {
            pulseScale = 1.18
            pulseGlow = 1.0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeInOut(duration: 0.55)) {
                pulseScale = 1.0
                pulseGlow = 0.0
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch state {
        case .idle:     return "Taya"
        case .pairing:  return "Pairing"
        case .syncing:  return "Syncing notes"
        case .complete: return "Up to date"
        }
    }

    private var accessibilityValue: String {
        if case .syncing(let current, let total) = state {
            return "\(current) of \(total)"
        }
        return ""
    }
}

#if DEBUG
struct TayaIntelligenceOrb_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TayaIntelligenceOrb(state: .idle, size: 160)
                .previewDisplayName("Idle")
            TayaIntelligenceOrb(state: .pairing, size: 160)
                .previewDisplayName("Pairing")
            TayaIntelligenceOrb(state: .syncing(current: 1, total: 3), size: 160)
                .previewDisplayName("Syncing 1 of 3")
            TayaIntelligenceOrb(state: .complete, size: 160)
                .previewDisplayName("Complete")
        }
        .padding(40)
    }
}
#endif
