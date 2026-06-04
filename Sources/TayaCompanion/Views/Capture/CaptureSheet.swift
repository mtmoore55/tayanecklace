import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Three-phase recording sheet:
/// - `.idle` — pulled-back orb, prompt to tap.
/// - `.listening` — orb blooms, breathes to a simulated audio level,
///   elapsed timer counts up.
/// - `.captured` — brief flourish (checkmark + "Captured"), then the
///   sheet dismisses. Real recording pipeline lands in step 6; the
///   `simulatedAudioLevel` function is the seam where mic input slots in.
struct CaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DataStore.self) private var store
    @State private var phase: Phase = .idle
    @State private var recordingStart: Date?
    @State private var finalElapsed: TimeInterval?

    /// Connectivity at the moment the sheet was presented. If non-ok when
    /// the user commits, the moment lands as `.pending` and the row will
    /// render the pending badge until `flushPendingMoments` drains it.
    var connectivity: ConnectivityStatus = .ok

    enum Phase: Equatable { case idle, listening, captured }

    private var orbSize: CGFloat {
        switch phase {
        case .idle:      return 200
        case .listening: return 280
        case .captured:  return 230
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                orbStack
                captionStack
                Spacer()
                recordPill
                    .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
    }

    // MARK: - Orb

    private var orbStack: some View {
        // The orb is the visual; control lives in `recordPill` below.
        // This outer TimelineView is the host's audio driver, so we
        // recompute `simulatedAudioLevel` per frame and pass it in
        // without needing a Timer + @State ratchet.
        TimelineView(
            .animation(minimumInterval: 1.0 / 30.0, paused: scenePhase != .active)
        ) { context in
            let level = phase == .listening
                ? simulatedAudioLevel(at: context.date)
                : 0
            ZStack {
                TayaIntelligenceOrb(
                    size: orbSize,
                    intensity: phase == .listening ? .listening : .idle,
                    audioLevel: level
                )
                if phase == .captured {
                    Image(systemName: "checkmark")
                        .font(.system(size: orbSize * 0.32, weight: .semibold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 300, height: 300, alignment: .center)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: orbSize)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: phase)
            .accessibilityLabel("Taya")
        }
        .frame(width: 300, height: 300)
    }

    // MARK: - Caption + timer

    @ViewBuilder
    private var captionStack: some View {
        switch phase {
        case .idle:
            Text("Capture a moment. Taya keeps the details so you don't have to.")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .transition(.opacity)
        case .listening:
            elapsedLabel
                .transition(.opacity)
        case .captured:
            if let finalElapsed {
                Text(formatElapsed(finalElapsed))
                    .font(Theme.titleM().monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Record pill

    private var recordPill: some View {
        Button(action: tapRecord) {
            HStack(spacing: 14) {
                pillIndicator
                Text(pillLabel)
                    .font(Theme.titleL().weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .tayaGlassCard(in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(phase == .captured)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: phase)
        .padding(.horizontal, 20)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var pillIndicator: some View {
        switch phase {
        case .idle:
            // Solid red dot — the "record" affordance.
            Circle()
                .fill(Color.red)
                .frame(width: 18, height: 18)
        case .listening:
            // Filled square — the universal "stop" symbol, in red.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.red)
                .frame(width: 16, height: 16)
        case .captured:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.green)
                .frame(width: 18, height: 18)
        }
    }

    private var pillLabel: String {
        switch phase {
        case .idle:      return "Record"
        case .listening: return "Stop"
        case .captured:  return "Captured"
        }
    }

    private var elapsedLabel: some View {
        TimelineView(.periodic(from: recordingStart ?? Date(), by: 1.0)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(recordingStart ?? context.date))
            Text(formatElapsed(elapsed))
                .font(Theme.titleM().monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - Chrome

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .padding(.trailing, 20)
        .accessibilityLabel("Close")
    }

    // MARK: - Behavior

    private func tapRecord() {
        switch phase {
        case .idle:
            recordingStart = Date()
            withAnimation { phase = .listening }
            Haptics.tap()
        case .listening:
            if let start = recordingStart {
                finalElapsed = max(0, Date().timeIntervalSince(start))
            }
            withAnimation { phase = .captured }
            Haptics.commit()
            // Demo-grade commit. Stamp `.pending` when the environment was
            // degraded at capture time — `flushPendingMoments` drains it
            // when connectivity returns.
            store.appendPhoneMoment(
                syncStatus: connectivity == .ok ? .synced : .pending
            )
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                await MainActor.run { dismiss() }
            }
        case .captured:
            break
        }
    }

    // MARK: - Audio simulation

    /// Slow, smooth 0…~0.55 level that gives the orb a gentle "breathing
    /// with you" feel rather than reacting to every syllable. Real mic
    /// metering will replace this — at that point, low-pass the input so
    /// it stays in roughly this same range and update cadence.
    private func simulatedAudioLevel(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        // Two slow waves only — no high-frequency components, no squaring.
        let a = 0.55 + 0.30 * sin(t * 0.9)      // ~7s period
        let b = 0.12 * sin(t * 2.0 + 1.2)       // ~3s period
        return max(0, min(0.55, a + b - 0.25))
    }

    // MARK: - Formatting

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private var accessibilityLabel: String {
        switch phase {
        case .idle:      return "Record a moment"
        case .listening: return "Stop recording"
        case .captured:  return "Captured"
        }
    }
}

#Preview {
    CaptureSheet()
        .environment(DataStore.seeded(now: Date()))
}
