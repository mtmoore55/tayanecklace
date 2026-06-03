import SwiftUI

/// Top-right pill combining necklace battery and the user's avatar in one
/// glass capsule. Two tap zones: the battery glyph reveals the necklace
/// hardware area; the avatar opens the Profile sheet.
struct NecklaceProfilePill: View {
    let ambient: AmbientState
    var onRevealHardware: () -> Void
    var onOpenProfile: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    private let height: CGFloat = 44
    private let avatarSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onRevealHardware) {
                batteryGlyph
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Necklace \(ambient.necklaceBattery) percent. Tap for hardware.")

            Button(action: onOpenProfile) {
                avatar
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(height: height)
        .background(
            Capsule(style: .continuous)
                .fill(Theme.glassFillStrong)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Theme.glassStrokeStrong, lineWidth: 0.75)
        )
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
            Image(systemName: batterySystemImage(forPercent: ambient.necklaceBattery))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.accent)
        }
    }

    private var avatar: some View {
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
}

#Preview {
    ZStack {
        Theme.backgroundGradient.ignoresSafeArea()
        VStack {
            HStack {
                Spacer()
                NecklaceProfilePill(ambient: .mock, onRevealHardware: {}, onOpenProfile: {})
            }
            .padding()
            Spacer()
        }
    }
}
