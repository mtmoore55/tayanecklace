import SwiftUI
import TayaIntelligence

/// Circular glass affordance for share / export actions. Uses the same
/// navy-tinted card recipe as the surrounding content cards with a white
/// glyph, so the control sits in the page's glass language rather than
/// punching out against it.
struct ShareGlassLabel: View {
    var systemImage: String = "square.and.arrow.up"
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Theme.primaryText)
            .frame(width: size, height: size)
            .tayaGlassCard(in: Circle())
    }
}
