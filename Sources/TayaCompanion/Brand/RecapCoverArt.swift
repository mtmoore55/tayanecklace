import SwiftUI

/// Procedurally drawn cover art for a Recap card. Builds a soft, painterly
/// `MeshGradient` from the TayaColors palette, seeded by the day so the
/// same date always renders the same picture across launches — different
/// days drift into their own shape and colour permutation. Interior mesh
/// points wander slowly via a `TimelineView` so each cover feels alive
/// without ever becoming distracting.
struct RecapCoverArt: View {
    let date: Date

    var body: some View {
        let seed = Calendar.current.startOfDay(for: date)
            .timeIntervalSinceReferenceDate
            .bitPattern
        var baseRNG = SplitMix64(seed: seed)
        var colorRNG = SplitMix64(seed: seed ^ 0xA5A5_A5A5_A5A5_A5A5)
        var phaseRNG = SplitMix64(seed: seed ^ 0x5A5A_5A5A_5A5A_5A5A)

        let base = basePoints(rng: &baseRNG)
        let colors = meshColors(rng: &colorRNG)
        let phases = driftPhases(rng: &phaseRNG)

        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let t = Float(context.date.timeIntervalSinceReferenceDate)
            MeshGradient(
                width: 3,
                height: 3,
                points: animatedPoints(base: base, phases: phases, t: t),
                colors: colors
            )
        }
    }

    private func basePoints(rng: inout SplitMix64) -> [SIMD2<Float>] {
        let jitter: Float = 0.18
        func j() -> Float { Float.random(in: -jitter...jitter, using: &rng) }

        // Corners pinned; edge midpoints drift along their edge; centre
        // drifts both axes. These are the day's *base* positions — the
        // animated layer wobbles around them.
        return [
            SIMD2(0,            0),
            SIMD2(0.5 + j(),    0),
            SIMD2(1,            0),
            SIMD2(0,            0.5 + j()),
            SIMD2(0.5 + j(),    0.5 + j()),
            SIMD2(1,            0.5 + j()),
            SIMD2(0,            1),
            SIMD2(0.5 + j(),    1),
            SIMD2(1,            1)
        ]
    }

    /// Phase offsets (radians) for the 9 mesh points. Corners get phases
    /// too but they're ignored — keeps the index math simple.
    private func driftPhases(rng: inout SplitMix64) -> [Float] {
        (0..<9).map { _ in Float.random(in: 0 ..< .pi * 2, using: &rng) }
    }

    private func animatedPoints(
        base: [SIMD2<Float>],
        phases: [Float],
        t: Float
    ) -> [SIMD2<Float>] {
        // Drift = small sinusoid. Two slightly different frequencies (≈14s
        // and ≈19s periods) so x and y don't move in lock-step; amplitude
        // is small enough to read as ambient rather than animated.
        let amplitude: Float = 0.04
        let omegaX: Float = .pi * 2 / 14
        let omegaY: Float = .pi * 2 / 19

        func drift(index: Int, axis: SIMD2<Float>) -> SIMD2<Float> {
            let p = phases[index]
            let dx = sin(omegaX * t + p) * amplitude * axis.x
            let dy = cos(omegaY * t + p * 1.3) * amplitude * axis.y
            return SIMD2(dx, dy)
        }

        // axis mask per point: 0 means pinned on that axis
        let axes: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 0),
            SIMD2(0, 1), SIMD2(1, 1), SIMD2(0, 1),
            SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 0)
        ]

        return zip(base.indices, base).map { i, p in
            p + drift(index: i, axis: axes[i])
        }
    }

    private func meshColors(rng: inout SplitMix64) -> [Color] {
        // Pure skyBlue + white. Keeps the cover sitting naturally inside
        // the app's surface language; the white cells become the soft
        // "light leak" highlight that drifts as the mesh animates.
        var palette: [Color] = [
            TayaColors.skyBlue,
            TayaColors.skyBlue,
            TayaColors.skyBlue,
            TayaColors.skyBlue,
            TayaColors.skyBlue,
            .white,
            .white,
            .white,
            .white
        ]
        palette.shuffle(using: &rng)
        return palette
    }
}

/// Deterministic 64-bit PRNG — same seed, same output. Local to the cover
/// system; not promoted to a shared util.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEAD_BEEF_CAFE_BABE : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

#Preview("Recap covers") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { offset in
                let day = Calendar.current.date(
                    byAdding: .day, value: -offset, to: Date()
                ) ?? Date()
                RecapCoverArt(date: day)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding()
    }
    .background(Theme.backgroundGradient.ignoresSafeArea())
}
