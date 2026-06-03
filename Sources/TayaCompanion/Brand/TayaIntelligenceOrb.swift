import SwiftUI

/// Ethereal, animated take on the Taya logomark. Each layer is *two*
/// passes through the same ring silhouette: a heavily-blurred halo that
/// gives the layer its soft volume, plus a near-sharp pass that is
/// masked to a moving angular arc so only part of the ring is in focus
/// at any moment. The focus arc and the ring itself rotate at different
/// rates, so the crisp section drifts around the shape — that's what
/// produces the "some parts blurred, some parts crisp, all the time"
/// feeling rather than a uniform soft glow.
///
/// Driven by `TimelineView(.animation)` so motion is continuous and
/// frame-locked (no `withAnimation` repeat loops to thrash).
///
/// Two intensity modes:
/// - `.idle` — slow drift, gentle breath, pulled back; for ambient surfaces.
/// - `.listening` — faster rotation and stronger breath; used while
///   recording. Pass `audioLevel` (0…1) to make the halo and breath
///   amplitude react to mic input — feeds straight from the audio
///   level meter in production, simulated by the host for now.
struct TayaIntelligenceOrb: View {
    enum Intensity { case idle, listening }

    var size: CGFloat = 220
    var intensity: Intensity = .idle
    /// 0…1 amplitude. Ignored when `intensity == .idle`. Anything past
    /// 1 is clamped — pre-normalize on the way in.
    var audioLevel: Double = 0

    @Environment(\.scenePhase) private var scenePhase

    private var clampedLevel: Double {
        intensity == .listening ? max(0, min(1, audioLevel)) : 0
    }

    var body: some View {
        TimelineView(.animation(paused: scenePhase != .active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                halo(t: t)
                ForEach(0..<Self.layers.count, id: \.self) { i in
                    layer(Self.layers[i], at: t)
                }
            }
            .frame(width: size, height: size)
            .compositingGroup()
            .blur(radius: 0.6) // micro-softening over everything to bind the layers
        }
        .accessibilityLabel("Taya intelligence")
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Layer rendering

    private func layer(_ l: OrbLayer, at t: TimeInterval) -> some View {
        let level = clampedLevel
        let speed = l.rotationSpeed * intensityMultiplier
        let breathSpeed = l.breathSpeed * intensityMultiplier
        let baseBreathAmp = l.breathAmplitude * (intensity == .listening ? 1.7 : 1.0)
        // Audio adds a *tiny* extra wobble on top of the base breath —
        // anything more reads as jitter rather than a living surface.
        let breathAmp = baseBreathAmp * (1.0 + level * 0.18)
        let focusSpeed = l.focusDriftSpeed * intensityMultiplier

        let ringRot = (t * speed + l.rotationOffset).truncatingRemainder(dividingBy: 360)
        let focusRot = (t * focusSpeed + l.focusOffset).truncatingRemainder(dividingBy: 360)
        let scale = 1.0 + sin(t * breathSpeed + l.breathPhase) * breathAmp

        // Idle dampens halo + focus opacity; listening adds the merest
        // halo lift from audio — small enough to keep the layered colors
        // legible rather than blowing the composite to white.
        let idleDampen = intensity == .idle ? 0.62 : 1.0
        let haloOpacity = l.haloOpacity * idleDampen * (1.0 + level * 0.12)
        let focusOpacity = l.focusOpacity * idleDampen

        return ZStack {
            // Diffuse halo — heavily blurred, slightly larger, full ring visible.
            TayaLogomark(size: size * l.scale * l.haloScale)
                .foregroundStyle(l.color)
                .blur(radius: l.haloBlur)
                .opacity(haloOpacity)

            // Focused arc — mostly crisp, masked to a soft-edged arc that
            // drifts independently of the ring rotation.
            TayaLogomark(size: size * l.scale)
                .foregroundStyle(l.color)
                .mask(
                    focusArcMask(arcDegrees: l.focusArcDegrees, fadeDegrees: l.focusFadeDegrees)
                        .rotationEffect(.degrees(focusRot))
                )
                .blur(radius: l.focusBlur)
                .opacity(focusOpacity)
        }
        .rotationEffect(.degrees(ringRot))
        .scaleEffect(scale)
        .blendMode(.plusLighter)
    }

    /// Angular mask: a central white arc (`arcDegrees` wide) fading to clear
    /// over `fadeDegrees` on each side. Centered at 12 o'clock; rotate to
    /// move the focus around the ring.
    private func focusArcMask(arcDegrees: Double, fadeDegrees: Double) -> some View {
        let half = (arcDegrees / 2) / 360
        let fade = fadeDegrees / 360
        // AngularGradient starts at the trailing edge (3 o'clock by default)
        // and sweeps clockwise. We place the bright arc around 0.5 so it's
        // visually centered after `.rotationEffect` aligns it later.
        let stops: [Gradient.Stop] = [
            .init(color: .clear, location: 0.0),
            .init(color: .clear, location: max(0.0, 0.5 - half - fade)),
            .init(color: .white, location: max(0.0, 0.5 - half)),
            .init(color: .white, location: min(1.0, 0.5 + half)),
            .init(color: .clear, location: min(1.0, 0.5 + half + fade)),
            .init(color: .clear, location: 1.0)
        ]
        return AngularGradient(stops: stops, center: .center, angle: .degrees(-90))
    }

    private func halo(t: TimeInterval) -> some View {
        let pulseSpeed = 0.7 * intensityMultiplier
        let pulse = 0.5 + 0.5 * sin(t * pulseSpeed)
        let base = intensity == .listening ? 0.4 : 0.14
        let level = clampedLevel
        // Audio nudges the outer halo a hair — keep this small.
        let haloOpacity = base * (0.7 + 0.3 * pulse) * (1.0 + level * 0.18)
        return Circle()
            .fill(
                RadialGradient(
                    colors: [
                        TayaColors.skyBlue.opacity(haloOpacity),
                        TayaColors.skyBlue.opacity(0)
                    ],
                    center: .center,
                    startRadius: size * 0.15,
                    endRadius: size * 0.6
                )
            )
            .blur(radius: 22)
    }

    private var intensityMultiplier: Double {
        intensity == .listening ? 1.55 : 1.0
    }

    // MARK: - Layer definitions

    private struct OrbLayer {
        let color: Color
        let scale: CGFloat

        // Ring (the whole shape) rotation
        let rotationSpeed: Double       // degrees per second
        let rotationOffset: Double

        // Breath (scale pulse)
        let breathSpeed: Double         // radians per second
        let breathPhase: Double
        let breathAmplitude: Double

        // Halo pass — heavily blurred, fills out the ring's "presence"
        let haloScale: CGFloat
        let haloBlur: CGFloat
        let haloOpacity: Double

        // Focus pass — sharper arc that drifts around the ring
        let focusOpacity: Double
        let focusBlur: CGFloat          // small (or 0) for a crisp arc
        let focusArcDegrees: Double     // size of the bright arc, e.g. 110
        let focusFadeDegrees: Double    // soft falloff on each end
        let focusDriftSpeed: Double     // independent of ring rotation
        let focusOffset: Double
    }

    private static let layers: [OrbLayer] = [
        // Sky-blue body
        OrbLayer(
            color: TayaColors.skyBlue,
            scale: 1.0,
            rotationSpeed: 6,
            rotationOffset: 0,
            breathSpeed: 0.6,
            breathPhase: 0,
            breathAmplitude: 0.035,
            haloScale: 1.08,
            haloBlur: 22,
            haloOpacity: 0.55,
            focusOpacity: 0.85,
            focusBlur: 0.8,
            focusArcDegrees: 110,
            focusFadeDegrees: 55,
            focusDriftSpeed: 14,
            focusOffset: 0
        ),
        // Deeper blue ghost — counter-rotating, broader halo
        OrbLayer(
            color: TayaColors.blue400,
            scale: 0.97,
            rotationSpeed: -4.5,
            rotationOffset: 72,
            breathSpeed: 0.5,
            breathPhase: 1.2,
            breathAmplitude: 0.045,
            haloScale: 1.12,
            haloBlur: 28,
            haloOpacity: 0.45,
            focusOpacity: 0.55,
            focusBlur: 2.2,
            focusArcDegrees: 95,
            focusFadeDegrees: 60,
            focusDriftSpeed: -11,
            focusOffset: 130
        ),
        // Cream warmth — softer focus, sleepier drift
        OrbLayer(
            color: TayaColors.cosmicLatte,
            scale: 0.99,
            rotationSpeed: 5,
            rotationOffset: 144,
            breathSpeed: 0.7,
            breathPhase: 2.6,
            breathAmplitude: 0.05,
            haloScale: 1.1,
            haloBlur: 20,
            haloOpacity: 0.4,
            focusOpacity: 0.55,
            focusBlur: 1.4,
            focusArcDegrees: 140,
            focusFadeDegrees: 70,
            focusDriftSpeed: 9,
            focusOffset: 220
        ),
        // White edge highlight — narrow, crisp arc that drifts fastest
        OrbLayer(
            color: Color.white,
            scale: 0.95,
            rotationSpeed: -7,
            rotationOffset: 216,
            breathSpeed: 0.42,
            breathPhase: 3.8,
            breathAmplitude: 0.03,
            haloScale: 1.06,
            haloBlur: 14,
            haloOpacity: 0.28,
            focusOpacity: 0.7,
            focusBlur: 0.4,
            focusArcDegrees: 70,
            focusFadeDegrees: 40,
            focusDriftSpeed: 22,
            focusOffset: 50
        ),
        // Cool blue depth — wide diffuse halo, faint focus
        OrbLayer(
            color: TayaColors.blue500.opacity(0.9),
            scale: 1.03,
            rotationSpeed: 3,
            rotationOffset: 288,
            breathSpeed: 0.55,
            breathPhase: 5.0,
            breathAmplitude: 0.04,
            haloScale: 1.16,
            haloBlur: 34,
            haloOpacity: 0.38,
            focusOpacity: 0.4,
            focusBlur: 3.5,
            focusArcDegrees: 130,
            focusFadeDegrees: 70,
            focusDriftSpeed: -6,
            focusOffset: 310
        )
    ]
}

#Preview {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 60) {
            TayaIntelligenceOrb(size: 220, intensity: .idle)
            TayaIntelligenceOrb(size: 220, intensity: .listening)
        }
    }
}
