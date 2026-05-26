import SwiftUI
import TayaIntelligence

struct NecklaceView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase
    @State private var presentedMoment: MomentRoute?

    // Mock device state. Phase later: real BLE bridge.
    private let battery: Int = 72
    private let signal: Int = 4 // 0…4
    private let firmware = "v1.2.3"
    private let serial = "TY-A1F7"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                NecklaceHero()
                batteryReadout
                section(eyebrow: "Connection") {
                    Card(padding: 4) {
                        VStack(spacing: 0) {
                            statusRow(
                                icon: "wave.3.right",
                                title: "Signal",
                                trailing: AnyView(signalBars)
                            )
                            Divider().padding(.leading, 50)
                            statusRow(
                                icon: "checkmark.circle",
                                title: "Pairing",
                                trailingText: "Connected"
                            )
                        }
                    }
                }
                section(eyebrow: "Device") {
                    Card(padding: 4) {
                        VStack(spacing: 0) {
                            statusRow(
                                icon: "cpu",
                                title: "Firmware",
                                trailingText: firmware
                            )
                            Divider().padding(.leading, 50)
                            statusRow(
                                icon: "number",
                                title: "Serial",
                                trailingText: serial
                            )
                        }
                    }
                }
                captureHistorySection
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, Theme.pageContentBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id)
                .environment(store)
        }
    }

    // MARK: - Battery readout

    /// Centered two-line readout under the 3D model: battery percent on
    /// top, estimated remaining time below.
    private var batteryReadout: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: batterySystemImage(forPercent: battery))
                    .font(.system(size: 16, weight: .regular))
                Text("\(battery)%")
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
        // Rough mock: 18 hours full → linear estimate.
        let hours = Double(battery) / 100.0 * 18.0
        if hours >= 1 {
            return "~\(Int(hours)) hours remaining"
        }
        return "Low battery"
    }

    // MARK: - Status row

    private func statusRow(
        icon: String,
        title: String,
        trailing: AnyView? = nil,
        trailingText: String? = nil
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(title)
                .font(Theme.bodyL())
            Spacer()
            if let text = trailingText {
                Text(text)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
            } else if let v = trailing {
                v
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var signalBars: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(i < signal ? Theme.accent : Theme.secondaryText.opacity(0.25))
                    .frame(width: 3, height: 6 + CGFloat(i) * 2)
            }
        }
    }

    // MARK: - Capture history

    private var captureHistorySection: some View {
        let necklaceCaptures = store.moments
            .filter { $0.source == .necklace }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)

        return section(eyebrow: "Recent captures") {
            if necklaceCaptures.isEmpty {
                Card {
                    Text("No captures from the necklace yet.")
                        .font(Theme.bodyL())
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(necklaceCaptures.enumerated()), id: \.element.id) { i, moment in
                            Button(action: whenIdle {
                                presentedMoment = MomentRoute(id: moment.id)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(moment.title)
                                            .font(Theme.bodyL())
                                            .foregroundStyle(Theme.primaryText)
                                            .lineLimit(1)
                                        Text(moment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(Theme.caption())
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if i < necklaceCaptures.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    /// Wrap a tap action so it only fires when no gesture is in progress —
    /// prevents a horizontal page-swipe from accidentally opening a sheet.
    private func whenIdle(_ action: @escaping () -> Void) -> () -> Void {
        return {
            guard gesturePhase == .idle else { return }
            action()
        }
    }
}

#Preview {
    NecklaceView()
        .environment(DataStore.seeded(now: Date()))
}

// MARK: - 3D hero

/// Hosts the necklace USDZ at the top of the Necklace view.
///
/// Two ambient behaviors layered together:
/// - **Yaw**: driven by the page's `\.pagerDistanceFromActive` env value
///   so the model rotates as the user swipes the page in or out.
/// - **Bob + shadow**: a slow vertical oscillation while idle, with a
///   ground shadow that widens / darkens as the necklace dips and
///   narrows / lightens as it lifts — giving the static view some life.
private struct NecklaceHero: View {
    @Environment(\.pagerDistanceFromActive) private var distance
    @State private var bobUp = false

    /// Max yaw applied when the adjacent page is fully centered.
    private static let maxYawDegrees: Double = 75
    private static let height: CGFloat = 260
    /// Vertical bob amplitude (±) and full period.
    private static let bobAmplitude: CGFloat = 6
    private static let bobPeriod: Double = 2.4

    private var bobAnimation: Animation {
        .easeInOut(duration: Self.bobPeriod / 2).repeatForever(autoreverses: true)
    }

    var body: some View {
        VStack(spacing: 0) {
            NecklaceModel(yawDegrees: yaw)
                .frame(maxWidth: .infinity)
                .frame(height: Self.height - 24)
                .offset(y: bobUp ? -Self.bobAmplitude : Self.bobAmplitude)
                .animation(bobAnimation, value: bobUp)

            shadow
                .padding(.top, -8)
        }
        .frame(height: Self.height)
        .onAppear { bobUp = true }
    }

    private var shadow: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Theme.primaryText.opacity(0.22),
                        Theme.primaryText.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 70
                )
            )
            .frame(width: 140, height: 18)
            .scaleEffect(x: bobUp ? 0.82 : 1.18, y: 1, anchor: .center)
            .opacity(bobUp ? 0.55 : 1.0)
            .animation(bobAnimation, value: bobUp)
    }

    private var yaw: Double {
        let clamped = max(-1, min(1, distance))
        return clamped * Self.maxYawDegrees
    }
}
