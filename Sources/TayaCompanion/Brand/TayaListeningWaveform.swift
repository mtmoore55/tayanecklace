import SwiftUI

/// In-pill listening visual for the chat composer. Translates the
/// `TayaIntelligenceOrb` aesthetic into a horizontal bar form so it
/// can live inside a text field's bounds.
///
/// Same layering trick as the orb: a diffuse blurred body underneath,
/// a sharper crest on top, and a focus arc that scans across the bars
/// over time so part of the wave reads as "lit" while the rest stays
/// soft. Sky-blue body, warm cream undertone, and a white highlight
/// — mirroring the orb's palette. Audio-reactive amplitude through
/// `audioLevel`; production wires a real mic meter into this seam, the
/// host simulates it for now.
///
/// Driven by `TimelineView(.animation)` so motion stays frame-locked
/// without animation churn.
struct TayaListeningWaveform: View {
    /// Per-frame audio amplitude in 0…1. Returns 0 when no mic source
    /// has been wired in. Closure form rather than a static value so a
    /// single TimelineView drives both motion and amplitude — no nested
    /// schedules, no redundant GPU submissions.
    var audioLevel: (Date) -> Double = { _ in 0 }
    /// Horizontal bar spacing target — actual count flexes to fit.
    var barWidth: CGFloat = 3
    var barSpacing: CGFloat = 4

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let count = max(8, Int((geo.size.width + barSpacing) / (barWidth + barSpacing)))
            TimelineView(
                .animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)
            ) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let level = max(0, min(1, audioLevel(context.date)))
                ZStack {
                    halo(in: geo.size, t: t, level: level)
                    ForEach(Self.layers.indices, id: \.self) { i in
                        barPass(Self.layers[i], in: geo.size, count: count, t: t, level: level)
                    }
                }
                .compositingGroup()
                .blur(radius: 0.4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityLabel("Listening")
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Halo

    private func halo(in size: CGSize, t: TimeInterval, level: Double) -> some View {
        let pulseSpeed = 0.9
        let pulse = 0.5 + 0.5 * sin(t * pulseSpeed)
        let base = 0.28
        let opacity = base * (0.75 + 0.25 * pulse) * (1.0 + level * 0.25)
        return RoundedRectangle(cornerRadius: size.height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        TayaColors.skyBlue.opacity(opacity * 0.4),
                        TayaColors.skyBlue.opacity(opacity),
                        TayaColors.skyBlue.opacity(opacity * 0.4)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .blur(radius: 10)
    }

    // MARK: - Bar pass

    private func barPass(_ layer: BarLayer, in size: CGSize, count: Int, t: TimeInterval, level: Double) -> some View {
        let focusCenter = focusCenter(at: t, layer: layer, count: count)

        let rendered = HStack(spacing: barSpacing) {
            ForEach(0..<count, id: \.self) { i in
                let h = barHeight(
                    index: i,
                    count: count,
                    t: t,
                    level: level,
                    layer: layer,
                    maxHeight: size.height
                )
                let focus = focusEnvelope(
                    index: i,
                    count: count,
                    center: focusCenter,
                    arc: layer.focusArc
                )
                let opacity = layer.baseOpacity * (1.0 + focus * layer.focusGain)
                Capsule(style: .continuous)
                    .fill(layer.color)
                    .frame(width: barWidth, height: h)
                    .opacity(min(1.0, opacity))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .blur(radius: layer.blur)
        .blendMode(.plusLighter)

        return rendered
    }

    // MARK: - Math

    /// Multi-component sine sum keyed on bar index so adjacent bars
    /// move together but not identically — that's what gives the
    /// silhouette a wave-like flow instead of a popcorn pattern.
    private func barHeight(
        index: Int,
        count: Int,
        t: TimeInterval,
        level: Double,
        layer: BarLayer,
        maxHeight: CGFloat
    ) -> CGFloat {
        let pos = Double(index) / Double(max(1, count - 1))
        let phase = pos * .pi * 2

        let a = sin(t * layer.speedA + phase * 1.8 + layer.phaseOffset)
        let b = sin(t * layer.speedB + phase * 0.9 + layer.phaseOffset * 1.3)
        let c = sin(t * layer.speedC + phase * 2.7 + layer.phaseOffset * 0.6)

        let mix = (a + b * 0.6 + c * 0.35) / 1.95   // back into ~[-1, 1]
        // Edge taper so the silhouette fades into the pill ends rather
        // than slamming into the rounded corners.
        let edge = sin(pos * .pi)

        // Idle motion is small; level scales the visible swing.
        let amp = layer.baseAmplitude + level * layer.audioAmplitude
        let factor = 0.5 + mix * amp * edge

        let minH: CGFloat = maxHeight * 0.12
        let maxH: CGFloat = maxHeight * layer.maxScale
        let raw = CGFloat(max(0, min(1, factor))) * maxH
        return max(minH, raw)
    }

    /// Position of the focus center as a fractional bar index (0…count).
    /// The center drifts across the wave continuously — see the orb's
    /// `focusDriftSpeed`. Each layer drifts at its own rate.
    private func focusCenter(at t: TimeInterval, layer: BarLayer, count: Int) -> Double {
        let span = Double(count)
        let cycle = max(1.0, layer.focusPeriod)
        let phase = (t / cycle).truncatingRemainder(dividingBy: 1.0)
        return phase * span
    }

    /// Soft-edged envelope around the focus center. `arc` is in
    /// fraction-of-bars units; falloff is cosine-shaped.
    private func focusEnvelope(index: Int, count: Int, center: Double, arc: Double) -> Double {
        let pos = Double(index)
        // Closest distance considering wrap-around so the focus arc
        // can cross the edge without snapping.
        let raw = abs(pos - center)
        let wrapped = min(raw, Double(count) - raw)
        let half = arc / 2
        guard wrapped < half else { return 0 }
        let n = wrapped / half                          // 0 at center, 1 at edge
        return 0.5 * (1.0 + cos(.pi * n))              // 1 at center, 0 at edge
    }

    // MARK: - Layers

    private struct BarLayer {
        let color: Color
        let baseOpacity: Double
        let blur: CGFloat
        let maxScale: CGFloat          // fraction of container height
        let baseAmplitude: Double
        let audioAmplitude: Double
        let speedA: Double
        let speedB: Double
        let speedC: Double
        let phaseOffset: Double
        let focusArc: Double           // in bar-units
        let focusGain: Double          // opacity boost at focus center
        let focusPeriod: Double        // seconds for the focus center to sweep across
    }

    private static let layers: [BarLayer] = [
        // Diffuse cool body — broad, heavily blurred, low opacity
        BarLayer(
            color: TayaColors.blue500.opacity(0.85),
            baseOpacity: 0.45,
            blur: 3.5,
            maxScale: 0.95,
            baseAmplitude: 0.20,
            audioAmplitude: 0.55,
            speedA: 1.7,
            speedB: 0.9,
            speedC: 2.6,
            phaseOffset: 0.0,
            focusArc: 9,
            focusGain: 0.4,
            focusPeriod: 5.5
        ),
        // Sky-blue main body
        BarLayer(
            color: TayaColors.skyBlue,
            baseOpacity: 0.70,
            blur: 1.0,
            maxScale: 0.85,
            baseAmplitude: 0.18,
            audioAmplitude: 0.50,
            speedA: 2.1,
            speedB: 1.2,
            speedC: 3.1,
            phaseOffset: 0.7,
            focusArc: 7,
            focusGain: 0.6,
            focusPeriod: 4.2
        ),
        // Cream warmth — softer, sleepier
        BarLayer(
            color: TayaColors.cosmicLatte.opacity(0.9),
            baseOpacity: 0.40,
            blur: 0.6,
            maxScale: 0.65,
            baseAmplitude: 0.16,
            audioAmplitude: 0.45,
            speedA: 1.5,
            speedB: 0.8,
            speedC: 2.4,
            phaseOffset: 2.0,
            focusArc: 11,
            focusGain: 0.5,
            focusPeriod: 6.8
        ),
        // White edge highlight — narrow, crisp, fastest focus drift
        BarLayer(
            color: Color.white,
            baseOpacity: 0.18,
            blur: 0.2,
            maxScale: 0.55,
            baseAmplitude: 0.14,
            audioAmplitude: 0.40,
            speedA: 2.6,
            speedB: 1.5,
            speedC: 3.6,
            phaseOffset: 3.4,
            focusArc: 5,
            focusGain: 2.0,
            focusPeriod: 3.1
        )
    ]
}

#Preview {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 24) {
            TayaListeningWaveform(audioLevel: { _ in 0 })
                .frame(height: 36)
                .padding(.horizontal, 16)
                .frame(maxWidth: 320)
                .background(Capsule().fill(.white.opacity(0.04)))
            TayaListeningWaveform(audioLevel: { _ in 0.35 })
                .frame(height: 36)
                .padding(.horizontal, 16)
                .frame(maxWidth: 320)
                .background(Capsule().fill(.white.opacity(0.04)))
            TayaListeningWaveform(audioLevel: { _ in 0.85 })
                .frame(height: 36)
                .padding(.horizontal, 16)
                .frame(maxWidth: 320)
                .background(Capsule().fill(.white.opacity(0.04)))
        }
    }
}
