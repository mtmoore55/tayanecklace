import SwiftUI
import TayaIntelligence

/// Individual nav item — interpolates between a compact circle and an
/// expanded pill based on `expandedness` (0…1). Driven by swipe progress
/// in the parent `TayaTopNav`.
///
/// Layout strategy:
/// - The icon always sits inside an HStack with the label.
/// - The label is given an explicit `.frame(width:)` that lerps from 0 →
///   `tab.estimatedLabelWidth`. This means the HStack's intrinsic width
///   accurately reflects what's visible at each stage, so a default
///   (centered) frame alignment keeps both compact (just icon) and
///   expanded (icon + label) content visually centered.
/// - The label keeps `.fixedSize(horizontal: true)` so its rendered text
///   stays at intrinsic width, and is clipped by the lerping frame plus
///   the outer Capsule clipShape so transient overflow is hidden.
struct NavItem: View {
    let tab: AppTab
    let expandedness: Double
    let expandedWidth: CGFloat
    let onTap: () -> Void

    private let compactWidth: CGFloat = 36
    private let height: CGFloat = 36
    private let iconTextSpacing: CGFloat = 6

    private var width: CGFloat {
        compactWidth + (expandedWidth - compactWidth) * CGFloat(expandedness)
    }

    private var textScale: CGFloat {
        0.6 + 0.4 * CGFloat(expandedness)
    }

    private var textFrameWidth: CGFloat {
        tab.estimatedLabelWidth * CGFloat(expandedness)
    }

    private var spacing: CGFloat {
        iconTextSpacing * CGFloat(expandedness)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: spacing) {
                Image(systemName: tab.iconSystemName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(TayaColors.oxfordBlue)

                Text(tab.label())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TayaColors.oxfordBlue)
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
        .accessibilityLabel(tab.label())
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
