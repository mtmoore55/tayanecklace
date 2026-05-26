import SwiftUI
import TayaIntelligence

/// Individual nav item — interpolates between a compact circle and an
/// expanded pill based on `expandedness` (0…1). The icon is provided as a
/// view via a builder so individual tabs can render dynamic glyphs (user
/// initial, weather, battery level) instead of a static SF Symbol.
struct NavItem<Icon: View>: View {
    let tab: AppTab
    let label: String
    let expandedness: Double
    let expandedWidth: CGFloat
    let icon: Icon
    let onTap: () -> Void

    private let compactWidth: CGFloat = 36
    private let height: CGFloat = 36
    private let iconWidth: CGFloat = 16
    private let iconTextSpacing: CGFloat = 6

    private var width: CGFloat {
        compactWidth + (expandedWidth - compactWidth) * CGFloat(expandedness)
    }

    private var textScale: CGFloat {
        0.6 + 0.4 * CGFloat(expandedness)
    }

    private var textFrameWidth: CGFloat {
        // Width the label needs at its largest. Estimate proportional to
        // character count so longer overrides (e.g. "Tonight" vs "Today")
        // still fit without truncation.
        let estimate = max(tab.estimatedLabelWidth, CGFloat(label.count) * 9)
        return estimate * CGFloat(expandedness)
    }

    private var spacing: CGFloat {
        iconTextSpacing * CGFloat(expandedness)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: spacing) {
                icon
                    .frame(width: iconWidth, height: iconWidth)

                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .opacity(expandedness)
                    .scaleEffect(textScale, anchor: .leading)
                    .frame(width: textFrameWidth, alignment: .leading)
                    .clipped()
            }
            .frame(width: width, height: height)
            .background(background)
            .clipShape(Capsule(style: .continuous))
            .shadow(
                color: Theme.cardShadow.opacity(expandedness * 0.6),
                radius: 6, x: 0, y: 2
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Crossfade between Blue50 (inactive) and white (active).
    private var background: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Theme.blue50)
                .opacity(1 - expandedness)
            Capsule(style: .continuous)
                .fill(Theme.cardSurface)
                .opacity(expandedness)
        }
    }
}
