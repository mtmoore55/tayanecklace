import SwiftUI
import TayaIntelligence

struct NecklaceView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.gesturePhase) private var gesturePhase

    // Mock device state. Phase later: real BLE bridge.
    private let battery: Int = 72
    private let signal: Int = 4 // 0…4
    private let firmware = "v1.2.3"
    private let serial = "TY-A1F7"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                batteryHero
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
    }

    // MARK: - Hero

    private var batteryHero: some View {
        Card {
            HStack(spacing: 18) {
                ZStack {
                    Circle().fill(TayaColors.skyBlue)
                    Circle()
                        .trim(from: 0, to: CGFloat(battery) / 100)
                        .stroke(
                            TayaColors.oxfordBlue.opacity(0.55),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Battery")
                        .font(Theme.eyebrow())
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(battery)%")
                        .font(.system(size: 32, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(TayaColors.oxfordBlue)
                    Text(timeRemainingLabel)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
            }
        }
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
                .foregroundStyle(TayaColors.oxfordBlue)
                .frame(width: 24)
            Text(title)
                .font(Theme.body())
            Spacer()
            if let text = trailingText {
                Text(text)
                    .font(Theme.body())
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
                    .fill(i < signal ? TayaColors.oxfordBlue : Theme.secondaryText.opacity(0.25))
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
                        .font(Theme.body())
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(necklaceCaptures.enumerated()), id: \.element.id) { i, moment in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(moment.title)
                                        .font(Theme.body())
                                        .lineLimit(1)
                                    Text(moment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(Theme.caption())
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
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
                .font(Theme.eyebrow())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }
}

#Preview {
    NecklaceView()
        .environment(DataStore.seeded(now: Date()))
}
